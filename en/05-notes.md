# Notes

## A Short Note on RiakCS

*Riak CS* is Basho's open source extension to Riak to allow your cluster to act as
a remote storage mechanism, comparable to (and compatible with) Amazon's
S3. There are several reasons you may wish to host your own cloud storage mechanism
(security, legal reasons, you already own lots of hardware, cheaper at scale).
This is not covered in this short book, though I may certainly be bribed to
write one.

## A Short Note on MDC

*MDC*, or Multi Data Center, is a commercial extension to Riak provided by Basho.
While the documentation is freely available, the source code is not. If you reach
a scale where keeping multiple Riak clusters in sync on a local or global scale is
necessary, I would recommend considering this option.
