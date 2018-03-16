#!/bin/bash

container_bop_main() {
    if (( $# < 1 )); then
        install_err 'must supply Root (for perl-Root)'
    fi
    local root=$1
    local root_lc=${root,,}
    local exe_prefix
    local base_image=bivio
    local app_root=$root
    local facade_uri=$root_lc
    case $1 in
        Artisans)
            exec_prefix=a
            ;;
        Bivio)
            app_root=Bivio::PetShop
            base_image=perl
            exec_prefix=b
            facade_uri=petshop
            ;;
        BivioOrg)
            exec_prefix=bo
            facade_uri=bivio.org
            ;;
        Sensorimotor)
            exec_prefix=sp
            ;;
        Societas)
            exec_prefix=s
            ;;
        Zoe)
            exec_prefix=zoe
            facade_uri=zoescore
            ;;
        *)
            install_err "$1: unknown Perl app"
            ;;
    esac
    umask 077
    install_tmp_dir
    mkdir container-conf
    cp ~/.netrc container-conf/netrc
    {
        echo '#!/bin/bash'
        declare -f container_bop_build
        cat <<EOF
build_image_base=biviosoftware/$base_image
build_image_name=biviosoftware/${root_lc}
build_maintainer='Bivio Software <go@bivio.biz>'

build_as_root() {
    install -m 400 \$build_guest_conf/netrc ~/.netrc
    container_bop_build '$root' '$exe_prefix' '$app_root' '$facade_uri'
    rm -f ~/.netrc
}

build_as_run_user() {
    return
}
EOF
    } > container-conf/build.sh
    install_repo_eval radiasoft/containers docker
}

container_bop_build() {
    local root=$1 exe_prefix=$2 app_root=$3 facade_uri=$4
    umask 022
    cd "$build_guest_conf"
    local build_d=$PWD
    local javascript_d=/usr/share/Bivio-bOP-javascript
    local flags=()
    if [[ $root == Bivio ]]; then
        mkdir "$javascript_d"
        # No channels here, because the image gets the channel tag
        git clone --recursive --depth 1 https://github.com/biviosoftware/javascript-Bivio
        cd javascript-Bivio
        bash build.sh "$javascript_d"
        cd ..
        rm -rf javascript-Bivio
        #TODO(robnagler) move this to master when in production
        flags=( --branch robnagler --single-branch )
        cat > /etc/bivio.bconf <<'EOF'
use Bivio::DefaultBConf;
Bivio::DefaultBConf->merge_dir({
    'Bivio::UI::Facade' => {
        http_host => 'www.bivio.biz',
        mail_host => 'bivio.biz',
    },
});
EOF
        chmod 444 /etc/bivio.bconf
    fi
    local app_d=${app_root//::/\/}
    local files_d=$app_d/files
    git clone "${flags[@]}" https://github.com/biviosoftware/perl-"$root" --depth 1
    mv perl-"$root" "$root"
    # POSTIT: radiasoft/rsconf/rsconf/component/btest.py
    local btest_d="/usr/share/btest"
    mkdir -p "$btest_d"
    rsync -aR $(find "$root" -name t -prune) "$btest_d"
    if [[ $root == Bivio ]]; then
        # POSIT: radiasoft/rsconf/rsconf/package_data/btest/bivio.bconf.jinja
        local src_d=/usr/share/Bivio-bOP-src
        mkdir -p "$src_d"
        rsync -aR "$root" "$src_d"
    fi
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
    local facades_d=/var/www/facades
    rm -rf "$facades_d"
    local tgt=$facades_d
    mkdir -p "$(dirname "$tgt")" "$tgt"
    cd "$files_d"
    local dirs
    if [[ -d ddl || -d plain ]]; then
	tgt=$tgt/$facade_uri
        # view is historical for Artisans (slideshow and extremeperl)
	dirs=( plain ddl )
        mkdir -p "$tgt"
    else
	dirs=( $(find * -type d -prune -print) )
    fi
    find "${dirs[@]}" -type l -print -o -type f -print \
	| tar Tcf - - | (cd "$tgt"; tar xpf -)
    (
        set -e
	set -x
        export BCONF=$build_d/build.bconf
        cat > "$BCONF" <<EOF
use strict;
use $app_root::BConf;
$app_root::BConf->merge_dir({
    'Bivio::UI::Facade' => {
        local_file_root => '$facades_d',
    },
    'Bivio::Ext::DBI' => {
        connection => 'Bivio::SQL::Connection::None',
    },
});
EOF
        bivio project link_facade_files
    )
    for facade in "$facades_d"/*; do
        if [[ ! -L $facade ]]; then
            mkdir -p "$facade/plain"
            ln -s "$javascript_d" "$facade/plain/b"
        fi
    done
    if [[ $facade_uri == bivio.org ]]; then
        (
            cd "$facades_d"
            ln -s bivio.org via.rob
        )
    fi
    # Apps mount subdirectories here so need to exist in the container
    (umask 022; mkdir -p /var/log /var/db /var/bkp /var/www/html)
}

container_bop_main "${install_extra_args[@]}"
