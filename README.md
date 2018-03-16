# How to build bop containers

```sh
cd ~/src/biviosoftware
gcl container-perl
cd container-perl
# Assumes registry is on current host
export build_push=1 build_docker_registry=$(hostname -f):5000
radia_run container-build
# Builds Bivio & PetShop
radia_run biviosoftware/container-bop Bivio
# BivioOrg, etc.
radia_run biviosoftware/container-bop BivioOrg
```

# testing

First time as root:

```sh
# Only needed for the current container, then read-only
chown vagrant:vagrant /var/www/facades/*/ddl
su - vagrant
bivio sql -f init_dbms
bivio sql -f create_test_db
```

Run:

```sh
export BIVIO_HOST_NAME=z50.bivio.biz BCONF=Bivio::PetShop BIVIO_HTTPD_PORT=8002 PERLLIB=~/src/perl
bivio httpd run
```

# TODO

* https://www.nginx.com/resources/wiki/start/topics/examples/reverseproxycachingexample/
* https://www.nginx.com/blog/nginx-caching-guide/
* maintenance pages need to be handled specially. logo inside the page along with the css
* proxy_cache_use_stale?? but how to prime the cache?
