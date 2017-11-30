### How to build bop containers

```
cd ~/src/biviosoftware
gcl container-bop
gcl container-perl
cd container-perl
# Assumes registry is on current host
export build_push=1 build_docker_registry=$(hostname -f):5000
curl radia.run | bash -s container-build
# Builds biviosoftware/bivio
curl radia.run | bash -s biviosoftware/container-bop Bivio b Bivio::PetShop petshop
# base image is biviosoftware/bivio
curl radia.run | bash -s biviosoftware/container-bop BivioOrg bo BivioOrg bivio.org
etc.
