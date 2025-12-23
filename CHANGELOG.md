# Change Logs

## v0.0.8

 - prevent long package name (>128 chars) and long version (>40 chars)
 - use lderror 998 for directly skip reg.404 preparation
 - upgrade dependencies


## v0.0.7

 - fix bug: incorrect id parsing in route which recognize path as part of version


## v0.0.6

 - upgrade dependencies and remove unused `request` to suppress npm vulnerability report


## v0.0.5

 - reject with 404 if id is empty.


## v0.0.4

 - skip 400 error, treat it as 404 and suppress error log for it.


## v0.0.3

 - add additional message when `version-type` can't be analyzed correctly


## v0.0.2

 - support function-based customized option (currently for `cachetime` and `force` option)


## v0.0.1

 - init release
