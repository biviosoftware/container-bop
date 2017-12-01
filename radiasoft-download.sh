#!/bin/bash

container_bop_main() {
    local root=$1 exe_prefix=$2
    local app_root=${3:-$root}
    local facade_uri=${4:-${root,,}}
    if (( $# < 2 )); then
        install_err 'must supply root and exe_prefix'
    fi
    umask 077
    install_tmp_dir
    mkdir container-conf
    cp ~/.netrc container-conf/netrc
    local base_image=bivio
    if [[ $root == Bivio ]]; then
        base_image=perl
    fi
    {
        echo '#!/bin/bash'
        declare -f container_bop_build
        cat <<EOF
build_image_base=biviosoftware/$base_image
build_image_name=biviosoftware/${root,,}
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
    local root=$1 exe_prefix=$2 app_root=$3 facade_uri=$3
    umask 022
    cd "$build_guest_conf"
    local build_dir=$PWD
    local javascript_dir=/usr/share/Bivio-bOP-javascript
    local flags=()
    if [[ $root == Bivio ]]; then
        mkdir "$javascript_dir"
        # No channels here, because the image gets the channel tag
        git clone --recursive --depth 1 https://github.com/biviosoftware/javascript-Bivio
        cd javascript-Bivio
        bash build.sh "$javascript_dir"
        cd ..
        rm -rf javascript-Bivio
        #TODO(robnagler) move this to master when in production
        flags=( --branch robnagler --single-branch )
        if [[ $root == Bivio ]]; then
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
    fi
    local files_dir=${app_root//::/\/}/files
    git clone "${flags[@]}" https://github.com/biviosoftware/perl-"$root" --depth 1
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
    rm -rf "$facades_dir"
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
        PERLLIB=$build_dir bivio project link_facade_files
    )
    for facade in "$facades_dir"/*; do
        if [[ ! -L $facade ]]; then
            mkdir -p "$facade/plain"
            ln -s "$javascript_dir" "$facade/plain/b"
        fi
    done
}

container_bop_main "${install_extra_args[@]}"
