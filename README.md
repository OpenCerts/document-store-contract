# certificate-contract

[![Build Status](https://travis-ci.org/gyng/ditherer.svg?branch=master)](https://travis-ci.org/gyng/ditherer)

## Setup

```
$ yarn install
$ yarn lint
$ yarn test
$ yarn truffle <command>
```

## Docker

Starts a test network and then runs lints and tests from the `truffle` container.

```
$ docker-compose up -d
$ docker-compose exec truffle yarn run test:ci
```
