#!/usr/bin/env bash
set -euo pipefail

# Validate format-string compatibility without pretending incomplete locale
# files are complete. Git for Windows and ubuntu-latest both provide Perl, so
# this stays usable from the maintainer's Git Bash release environment without
# adding a language runtime solely for validation.
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
cd "$repo_root"

if ! command -v perl >/dev/null 2>&1; then
    echo "ERROR: Perl is required for localization validation (it is bundled with Git for Windows)." >&2
    exit 2
fi

perl - Decursive/Localization <<'PERL'
use strict;
use warnings;
use utf8;

my $locale_dir = shift @ARGV;
my $base_file = "$locale_dir/enUS.lua";
my $failed = 0;

sub read_text {
    my ($path) = @_;
    open my $handle, '<:encoding(UTF-8)', $path
        or die "ERROR: cannot read $path: $!\n";
    local $/;
    return <$handle>;
}

sub format_signature {
    my ($value) = @_;
    my @signature;

    while ($value =~ /%(?:%|(?:\d+\$)?[-+ #0]*(?:\d+|\*)?(?:\.(?:\d+|\*))?[hlL]?([cdeEfgGiouqsxX]))/g) {
        push @signature, $1 if defined $1;
    }

    return join ',', @signature;
}

sub parse_locale {
    my ($path) = @_;
    my $source = read_text($path);
    my %strings;

    while ($source =~ /L\["([^"]+)"\]\s*=\s*(?:\[(=*)\[(.*?)\]\2\]|"((?:\\.|[^"\\])*)")/sg) {
        my ($key, $long_value, $quoted_value) = ($1, $3, $4);
        my $value = defined $long_value ? $long_value : $quoted_value;

        if (exists $strings{$key}) {
            print STDERR "ERROR: $path assigns localization key $key more than once.\n";
            $failed = 1;
            next;
        }

        $strings{$key} = format_signature($value);
    }

    return \%strings;
}

my $base = parse_locale($base_file);
my @locale_files = sort grep { $_ ne $base_file } glob "$locale_dir/*.lua";
my $base_count = scalar keys %{$base};

print "Localization coverage (enUS baseline: $base_count keys)\n";

for my $path (@locale_files) {
    my ($locale) = $path =~ m{/([^/]+)\.lua$};
    my $strings = parse_locale($path);
    my $translated = 0;
    my $extra = 0;

    for my $key (sort keys %{$strings}) {
        if (!exists $base->{$key}) {
            $extra++;
            next;
        }

        $translated++;
        if ($strings->{$key} ne $base->{$key}) {
            my $expected = $base->{$key} eq '' ? '(none)' : $base->{$key};
            my $actual = $strings->{$key} eq '' ? '(none)' : $strings->{$key};
            print STDERR "ERROR: $locale key $key has format signature [$actual]; expected [$expected].\n";
            $failed = 1;
        }
    }

    my $missing = $base_count - $translated;
    my $coverage = $base_count ? 100 * $translated / $base_count : 100;
    printf "  %-4s %3d/%3d translated (%5.1f%%), %3d missing, %2d extra\n",
        $locale, $translated, $base_count, $coverage, $missing, $extra;
}

if ($failed) {
    print STDERR "Localization validation FAILED. Incomplete translations are informational; duplicate keys and incompatible format signatures are errors.\n";
    exit 1;
}

print "Localization validation passed. Incomplete translations are reported but do not fail the build.\n";
PERL
