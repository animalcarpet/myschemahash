# myschemahash

## General
myschemahash is simple SQL only utility for verifying that the objects of a
schema match a known-good state. It provides a quick test that will
allow, for example, QA and PRODUCTION schemas to be compared after a release
or slave servers against a master.

It will not identify where any difference are, just that they exist
(mysqldiff would be an appropriate tool to make that sort of comparison).
The function can be used with TAP-emitting assertions which would
allow it to be included within a wider testing regime with myTAP.

Schema object types tested are:

* tables
* columns
* contraints
* indexes
* triggers
* views
* routines and parameters
* events


## Installation
Select the script version to match your version of MySQL and install to the tap schema:

```
mysql -u ${MYOPTS} < myschemahash-5.5.sql
```

## Operation
myschemahash will generate a SHA-1 of all the non-volatile object defintions in
a given database instance. It does this by querying object definitions in
the information_schema tables. The resulting hash can then be compared
against another, presumed, similar schema definition. Volatile data in these
tables e.g. timestamps for create date and last update are skipped but other
types which can affect operation, such as sql_mode in routines, are not.

Like other utilities that use SHA-1 hashes, it is not necessary to use the
entire hash to make a comparison, even a small subset of the characters will
suffice because of the unlikely possibility of a collision. 

Run as standalone function
```
% mysql --batch --raw --skip-column-names --execute "SELECT tap.myschemahash('dbbame')"
```
or to use with TAP

```
% mysql --batch --raw --skip-column-names --execute "SELECT tap.myschemahash_get('dbbame')"
% mysql --batch --raw --skip-column-names --execute "SELECT tap.myschemahash_is('dbbame','2356af')"
```

### Notes

The MySQL information_schema is constantly evolving with columns added as new
functionality is added to the database. In particular, additional columns were
added to information_schema.columns in versions 5.6.4 and 5.7.6. In addition,
there is a rather insidious bug in the 5.7 information_schema so it is not
always possible to get an accurate value for the character_maximum_length and
character_octet_length in this version, hence these columns are ignored in 5.7.

myschemahash uses the GROUP_CONCAT() function, this has a default of 1024 characters
which will be insuficient when working with anything other than the most trivial schema
definitions. GROUP_CONCAT will warn rather than error if the limit is breached so
you should set the group_concat_max_len variable to something more suitable.

```
SET SESSION group_concat_max_len = 1000000;
```

See https://bugs.mysql.com/bug.php?id=78041

### Public Repository

The source code is available at
[GitHub](http://github.com/animalcarpet/myschemahash/).


### Author

[Paul Campbell](https://github.com/animalcarpet)



### Copyright and Licence

Copyright (c) 2019 Paul Campbell. Some rights reserved.

The full licence is available in a separate LICENSE file.

