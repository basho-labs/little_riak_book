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

## Locks, a cautionary tale

While assembling the *Writing Applications* guide, I tried to develop a data model that
would allow for reliable locking without strong consistency. That
attempt failed, but rather than throw the idea away entirely, I
decided to include it here to illustrate the complexities of coping
with eventual consistency.

Basic premise: multiple workers may be assigned data sets to process,
but each data set should be assigned to no more than one worker.

In the absence of strong consistency, the best an application can do
is use the `pr` and `pw` parameters (primary read, primary write) with
a value of `quorum` or `n_val`.

So, common features to all of these models:

* Lock for any given data set is a known key
* Value is a unique identifier for the worker

### Lock, a first draft

#### Sequence

Bucket: `allow_mult=false`

1. Worker reads with `pr=quorum` to determine whether a lock exists
2. If it does, move on to another data set
3. If it doesn't, create a lock with `pw=quorum`
4. Process data set to completion
5. Remove the lock

#### Failure scenario

1. Worker #1 reads the non-existent lock
2. Worker #2 reads the non-existent lock
3. Worker #2 writes its ID to the lock
4. Worker #2 starts processing the data set
4. Worker #1 writes its ID to the lock
5. Worker #1 starts processing the data set

### Lock, a second draft

Bucket: `allow_mult=false`

#### Sequence

1. Worker reads with `pr=quorum` to determine whether a lock exists
2. If it does, move on to another data set
3. If it doesn't, create a lock with `pw=quorum`
4. Read lock again with `pr=quorum`
5. If the lock exists with another worker's ID, move on to another
   data set
6. Process data set to completion
7. Remove the lock

#### Failure scenario

1. Worker #1 reads the non-existent lock
2. Worker #2 reads the non-existent lock
3. Worker #2 writes its ID to the lock
4. Worker #2 reads the lock and sees its ID
5. Worker #1 writes its ID to the lock
6. Worker #1 reads the lock and sees its ID
7. Both workers process the data set


If you've done any programming with threads before, you'll recognize
this as a common problem with non-atomic lock operations.

### Lock, a third draft

Bucket: `allow_mult=true`

#### Sequence

1. Worker reads with `pr=quorum` to determine whether a lock exists
2. If it does, move on to another data set
3. If it doesn't, create a lock with `pw=quorum`
4. Read lock again with `pr=quorum`
5. If the lock exists with another worker's ID **or** the lock
contains siblings, move on to another data set
6. Process data set to completion
7. Remove the lock

#### Failure scenario

1. Worker #1 reads the non-existent lock
2. Worker #2 reads the non-existent lock
3. Worker #2 writes its ID to the lock
5. Worker #1 writes its ID to the lock
6. Worker #1 reads the lock and sees a conflict
7. Worker #2 reads the lock and sees a conflict
8. Both workers move on to another data set

### Lock, a fourth draft

Bucket: `allow_mult=true`

#### Sequence

1. Worker reads with `pr=quorum` to determine whether a lock exists
2. If it does, move on to another data set
3. If it doesn't, create a lock with `pw=quorum` and a timestamp
4. Read lock again with `pr=quorum`
5. If the lock exists with another worker's ID **or** the lock
contains siblings **and** its timestamp is not the earliest, move on
to another data set
6. Process data set to completion
7. Remove the lock


#### Failure scenario

1. Worker #1 reads the non-existent lock
2. Worker #2 reads the non-existent lock
3. Worker #2 writes its ID and timestamp to the lock
4. Worker #2 reads the lock and sees its ID
5. Worker #2 starts processing the data set
6. Worker #1 writes its ID and timestamp to the lock
7. Worker #1 reads the lock and sees its ID with the lowest timestamp
8. Worker #1 starts processing the data set

At this point I may hear you grumbling: clearly worker #2 would have
the lower timestamp because it attempted its write first, and thus #1
would skip the data set and try another one.

Even *if* both workers are running on the same server (and thus
*probably* have timestamps that can be compared)[^clock-comparisons],
perhaps worker #1 started its write earlier but contacted an overloaded cluster
member that took longer to process the request.

[^clock-comparisons]: An important part of any distributed systems
discussion is the fact that clocks are inherently untrustworthy, and
thus calling any event the "last" to occur is an exercise in faith:
faith that a system clock wasn't set backwards in time by `ntpd` or an
impatient system administrator, faith that all clocks involved are in
perfect sync.

    And, to be clear, perfect synchronization of clocks across
    multiple systems is unattainable. Google is attempting to solve
    this by purchasing lots of atomic and GPS clocks at great expense,
    and even that only narrows the margin of error.


The same failure could occur if, instead of using timestamps for
comparison purposes, the ID of each worker was used for comparison
purposes. All it takes is for one worker to read its own write before
another worker's write request arrives.

### Conclusion

We can certainly come up with algorithms that limit the number of
times that multiple workers tackle the same job, but I have yet to
find one that guarantees exclusion.

What I found surprising about this exercise is that none of the
failure scenarios required some of the odder edge conditions that can
cause unexpected outcomes. For example, `pw=quorum` writes will return
an error to the client if 2 of the primary servers are not available,
but the value will *still* be written to the 3rd server and 2 fallback
servers. Predicting what will happens the next time someone tries to
read the key is challenging.

None of these algorithms required deletion of a value, but that is
particularly fraught with peril. It's not difficult to construct
scenarios where deleted values reappear if servers are temporarily
unavailable during the deletion request.
