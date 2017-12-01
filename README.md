# How to build bop containers

```sh
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

/etc/bivio.bconf - vagrant
mkdir -p log logbop db
docker run -it --rm --network=host -v $PWD/httpd.conf.jinja:/etc/httpd/conf/httpd.conf -v $PWD/petshop.bconf.jinja:/etc/bivio.bconf -v $PWD/log:/var/log/httpd -v $PWD/logbop:/var/log/bop: -v $PWD/db:/var/db/petshop -v /var/run/postgresql/.s.PGSQL.5432:/var/run/postgresql/.s.PGSQL.5432 v5.bivio.biz:5000/biviosoftware/bivio /usr/sbin/httpd -DFOREGROUND


https://www.nginx.com/resources/wiki/start/topics/examples/reverseproxycachingexample/
https://www.nginx.com/blog/nginx-caching-guide/
caching configuration for nginx, need to ensure cookies are not returned for static files

maintenance pages need to be handled specially. logo inside the page along with the css
proxy_cache_use_stale?? but how to prime the cache?
