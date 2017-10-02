#!/bin/bash
build_image_base=biviosoftware/perl
build_maintainer="Bivio Software <$build_type@bivio.biz>"

build_as_root() {
    curl radia.run | bash -s biviosoftware/container-bop Bivio b Bivio::PetShop petshop
}

build_as_run_user() {
    return
}
