# Notes

## A Short Note on MDC

MDC, or Multi Data Center, is a commercial extention to Riak provided by Basho.
While the documentation is freely available, the source code is not. If you get
the scale where keeping multiple Riak cluster in sync across the globe is 
necessary, I would recommend considering this option.

## A Short Note on RiakCS

RiakCS is Basho's commercial extension to Riak to allow your cluster to act as
a remote storage mechanism, comparable to (and compatible with) Amazon's
S3. There are several reasons you may wish to host your own cloud storage mechanism
(security, legal reasons, you already own lots of hardware, cheaper at scale).
