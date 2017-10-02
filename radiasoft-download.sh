#!/bin/bash

# Testing
# docker run
#
# docker run -u vagrant -v /var/run/postgresql/.s.PGSQL.5432:/var/run/postgresql/.s.PGSQL.5432 --rm -it --network=host biviosoftware/bop
# . ~/.bashrc
# export BIVIO_HOST_NAME=z50.bivio.biz BCONF=Bivio::PetShop BIVIO_HTTPD_PORT=8002 PERLLIB=~/src/perl
# bivio dev setup
# (cd $PERLLIB/Bivio && git checkout robnagler && rm -rf $(ls | grep -v PetShop))
# Only the first time:
#   bivio sql init_dbms
#   ctd
# bivio httpd run
container_bop_main() {
    if (( $EUID != 0 )); then
        install_err 'must be run as root'
    fi
    umask 022
    install_tmp_dir
    local build_dir=$PWD
    local javascript_dir=/usr/share/Bivio-bOP-javascript
    mkdir "$javascript_dir"
    # No channels here, because the image gets the channel tag
    git clone --recursive --depth 1 https://github.com/biviosoftware/javascript-Bivio
    cd javascript-Bivio
    bash build.sh "$javascript_dir"
    cd ..
    rm -rf javascript-Bivio
    local exe_prefix=b
    local root=Bivio
    local facade_uri=petshop
    local app_root=Bivio::PetShop
    local files_dir=${app_root//::/\/}/files
    #TODO(robnagler) move this to master when in production
    git clone --branch robnagler --single-branch https://github.com/biviosoftware/perl-"$root" --depth 1
    mv perl-"$root" "$root"
    perl -p -e "s{EXE_PREFIX}{$exe_prefix}g;s{ROOT}{$root}g" <<'EOF' > Makefile.PL
use strict;
require 5.005;
use ExtUtils::MakeMaker ();
use File::Find ();
my($_EXE_FILES) = [];
my($_PM) = {};
File::Find::find(sub {
    if (-d $_ && $_ =~ m#((^|/)(CVS|\.git|old|t)|-|\.old)$#) {
	$File::Find::prune = 1;
	return;
    }
    my($file) = $File::Find::name;
    $file =~ s#^\./##;
    push(@$_EXE_FILES, $file)
	if $file =~ m{(?:^|/)(?:EXE_PREFIX-[-\w]+$)$|Bivio/Util/bivio$};
    # $(INST_LIBDIR) is where MakeMaker copies packages during
    # the build process.  The variable is interpolated by make.
    $_PM->{$file} = '$(INST_LIBDIR)/' . $file
	if $file =~ /\.pm$/;
    return;
}, 'ROOT');
ExtUtils::MakeMaker::WriteMakefile(
	 NAME => 'ROOT',
     ABSTRACT => 'ROOT',
      VERSION => '1.0',
    EXE_FILES => $_EXE_FILES,
	 'PM' => $_PM,
       AUTHOR => 'Bivio',
    PREREQ_PM => {},
);
EOF
    perl Makefile.PL DESTDIR=/ INSTALLDIRS=vendor < /dev/null
    make POD2MAN=true
    make POD2MAN=true pure_install
    local facades_dir=/var/www/facades
    local tgt=$facades_dir
    mkdir -p "$(dirname "$tgt")" "$tgt"
    cd "$files_dir"
    local dirs
    if [[ -d ddl || -d plain ]]; then
	tgt=$tgt/$facade_uri
	dirs=( view plain ddl )
        mkdir -p "$tgt"
    else
	dirs=( $(find * -type d -prune -print) )
    fi
    find "${dirs[@]}" -type l -print -o -type f -print \
	| tar Tcf - - | (cd "$tgt"; tar xpf -)
    (
        set -e
	set -x
        export BCONF=$build_dir/build.bconf
        cat > "$BCONF" <<EOF
use strict;
use $app_root::BConf;
$app_root::BConf->merge_dir({
    'Bivio::UI::Facade' => {
        local_file_root => '$facades_dir',
    },
    'Bivio::Ext::DBI' => {
        connection => 'Bivio::SQL::Connection::None',
    },
});
EOF
        if [[ $app_root != BoulderSoftwareClub ]]; then
            PERLLIB=$build_dir bivio project link_facade_files
        fi
    )
    for facade in "$facades_dir"/*; do
        if [[ ! -L $facade ]]; then
            mkdir -p "$facade/plain"
            ln -s "$javascript_dir" "$facade/plain/b"
        fi
    done
}

container_bop_main "${install_extra_args[@]}"
