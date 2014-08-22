# Operators

<!-- What Riak is famous for is its simplicity to operate and stability at increasing scales. -->

In some ways, Riak is downright mundane in its role as the easiest
NoSQL database to operate. Want more servers? Add them. A network
cable is cut at 2am? Deal with it after a few more hours of
sleep. Understanding this integral part of your application stack is
still important, however, despite Riak's reliability.

We've covered the core concepts of Riak, and I've provided a taste of
how to use it, but there is more to the database than that. There are
details you should know if you plan on operating a Riak cluster of
your own.

## Clusters

Up to this point you've conceptually read about "clusters" and the "Ring" in
nebulous summations. What exactly do we mean, and what are the practical
implications of these details for Riak developers and operators?

A *cluster* in Riak is a managed collection of nodes that share a common Ring.

<h3>The Ring</h3>

*The Ring* in Riak is actually a two-fold concept.

Firstly, the Ring represents the consistent hash partitions (the partitions
managed by vnodes). This partition range is treated as circular, from 0 to
2^160-1 back to 0 again. (If you're wondering, yes this means that we are
limited to 2^160 nodes, which is a limit of a 1.46 quindecillion, or
`1.46 x 10^48`, node cluster. For comparison, there are only `1.92 x 10^49`
[silicon atoms on Earth](http://education.jlab.org/qa/mathatom_05.html).)

When we consider replication, the N value defines how many nodes an object is
replicated to. Riak makes a best attempt at spreading that value to as many
nodes as it can, so it copies to the next N adjacent nodes, starting with the
primary partition and counting around the Ring, if it reaches the last
partition, it loops around back to the first one.

Secondly, the Ring is also used as a shorthand for describing the state of the
circular hash ring I just mentioned. This Ring (aka *Ring State*) is a
data structure that gets passed around between nodes, so each knows the state
of the entire cluster. Which node manages which vnodes? If a node gets a
request for an object managed by other nodes, it consults the Ring and forwards
the request to the proper nodes. It's a local copy of a contract that all of
the nodes agree to follow.

Obviously, this contract needs to stay in sync between all of the nodes. If a node is permanently taken
offline or a new one added, the other nodes need to readjust, balancing the partitions around the cluster,
then updating the Ring with this new structure. This Ring state gets passed between the nodes by means of
a *gossip protocol*.

<h3>Gossip and CMD</h3>

Riak has two methods of keeping nodes current on the state of the Ring. The first, and oldest, is the *gossip protocol*. If a node's state in the cluster is altered, information is propagated to other nodes. Periodically, nodes will also send their status to a random peer for added consistency.

A newer method of information exchange in Riak is *cluster metadata* (CMD), which uses a more sophisticated method (plum-tree, DVV consistent state) to pass large amounts of metadata between nodes. The superiority of CMD is one of the benefits of using bucket types in Riak 2.0, discussed below.

In both cases, propagating changes in Ring is an asynchronous operation, and can take a couple minutes depending on Ring size.

<!-- Transfers will not start while a gossip is in progress. -->

<h3>How Replication Uses the Ring</h3>

Even if you are not a programmer, it's worth taking a look at this Ring example. It's also worth
remembering that partitions are managed by vnodes, and in conversation are sometimes interchanged,
though I'll try to be more precise here.

Let's start with Riak configured to have 8 partitions, which are set via `ring_creation_size`
in the `etc/riak.conf` file (we'll dig deeper into this file later).

```bash
## Number of partitions in the cluster (only valid when first
## creating the cluster). Must be a power of 2, minimum 8 and maximum
## 1024.
## 
## Default: 64
## 
## Acceptable values:
##   - an integer
ring_size = 8
```

In this example, I have a total of 4 Riak nodes running on `riak@AAA.cluster`,
`riak@BBB.cluster`, `riak@CCC.cluster`, and `riak@DDD.cluster`, each with two partitions (and thus vnodes)

Riak has the amazing, and dangerous, `attach` command that attaches an Erlang console to a live Riak
node, with access to all of the Riak modules.

The `riak_core_ring:chash(Ring)` function extracts the total count of partitions (8), with an array
of numbers representing the start of the partition, some fraction of the 2^160 number, and the node
name that represents a particular Riak server in the cluster.

```bash
$ bin/riak attach
(riak@AAA.cluster)1> {ok,Ring} = riak_core_ring_manager:get_my_ring().
(riak@AAA.cluster)2> riak_core_ring:chash(Ring).
{8,
 [{0,'riak@AAA.cluster'},
  {182687704666362864775460604089535377456991567872, 'riak@BBB.cluster'},
  {365375409332725729550921208179070754913983135744, 'riak@CCC.cluster'},
  {548063113999088594326381812268606132370974703616, 'riak@DDD.cluster'},
  {730750818665451459101842416358141509827966271488, 'riak@AAA.cluster'},
  {913438523331814323877303020447676887284957839360, 'riak@BBB.cluster'},
  {1096126227998177188652763624537212264741949407232, 'riak@CCC.cluster'},
  {1278813932664540053428224228626747642198940975104, 'riak@DDD.cluster'}]}
```

To discover which partition the bucket/key `food/favorite` object would be stored in, for example,
we execute `riak_core_util:chash_key( {<<"food">>, <<"favorite">>} )` and get a wacky 160 bit Erlang
number we named `DocIdx` (document index).

Just to illustrate that Erlang binary value is a real number, the next line makes it a more
readable format, similar to the ring partition numbers.

```bash
(riak@AAA.cluster)3> DocIdx = 
(riak@AAA.cluster)3> riak_core_util:chash_key({<<"food">>,<<"favorite">>}).
<<80,250,1,193,88,87,95,235,103,144,152,2,21,102,201,9,156,102,128,3>>

(riak@AAA.cluster)4> <<I:160/integer>> = DocIdx. I.
462294600869748304160752958594990128818752487427
```

With this `DocIdx` number, we can order the partitions, starting with first number greater than
`DocIdx`. The remaining partitions are in numerical order, until we reach zero, then
we loop around and continue to exhaust the list.

```bash
(riak@AAA.cluster)5> Preflist = riak_core_ring:preflist(DocIdx, Ring).
[{548063113999088594326381812268606132370974703616, 'riak@DDD.cluster'},
 {730750818665451459101842416358141509827966271488, 'riak@AAA.cluster'},
 {913438523331814323877303020447676887284957839360, 'riak@BBB.cluster'},
 {1096126227998177188652763624537212264741949407232, 'riak@CCC.cluster'},
 {1278813932664540053428224228626747642198940975104, 'riak@DDD.cluster'},
 {0,'riak@AAA.cluster'},
 {182687704666362864775460604089535377456991567872, 'riak@BBB.cluster'},
 {365375409332725729550921208179070754913983135744, 'riak@CCC.cluster'}]
```

So what does all this have to do with replication? With the above list, we simply replicate a write
down the list N times. If we set N=3, then the `food/favorite` object will be written to
the `riak@DDD.cluster` node's partition `5480631...` (I truncated the number here),
`riak@AAA.cluster` partition `7307508...`, and `riak@BBB.cluster` partition `9134385...`.

If something has happened to one of those nodes, like a network split
(confusingly also called a partition---the "P" in "CAP"), the remaining
active nodes in the list become candidates to hold the data.

So if the node coordinating the write could not reach node
`riak@AAA.cluster` to write to partition `7307508...`, it would then attempt
to write that partition `7307508...` to `riak@CCC.cluster` as a fallback
(it's the next node in the list preflist after the 3 primaries).

The way that the Ring is structured allows Riak to ensure data is always
written to the appropriate number of physical nodes, even in cases where one
or more physical nodes are unavailable. It does this by simply trying the next
available node in the preflist.

<h3>Hinted Handoff</h3>

When a node goes down, data is replicated to a backup node. This is
not permanent; Riak will periodically examine whether each vnode
resides on the correct physical node and hands them off to the proper
node when possible.

As long as the temporary node cannot connect to the primary, it will continue
to accept write and read requests on behalf of its incapacitated brethren.

Hinted handoff not only helps Riak achieve high availability, it also facilitates
data migration when physical nodes are added or removed from the Ring.


## Managing a Cluster

Now that we have a grasp of the general concepts of Riak, how users query it,
and how Riak manages replication, it's time to build a cluster. It's so easy to
do, in fact, I didn't bother discussing it for most of this book.

<h3>Install</h3>

The Riak docs have all of the information you need to [install](http://docs.basho.com/riak/latest/tutorials/installation/) it per operating system. The general sequence is:

1. Install Erlang
2. Get Riak from a package manager (<em>a la</em> `apt-get` or Homebrew), or build from source (the results end up under `rel/riak`, with the binaries under `bin`).
3. Run `riak start`

Install Riak on four or five nodes---five being the recommended safe minimum for production. Fewer nodes are OK during software development and testing.

<h3>Command Line</h3>

Most Riak operations can be performed though the command line. We'll concern ourselves with two commands: `riak` and `riak-admin`.

<h4>riak</h4>

Simply typing the `riak` command will give a usage list. If you want more information, you can try `riak help`.

```bash
Usage: riak <command>
where <command> is one of the following:
    { help | start | stop | restart | ping | console | attach
      attach-direct | ertspath | chkconfig | escript | version | getpid
      top [-interval N] [-sort { reductions | memory | msg_q }] [-lines N] } |
      config { generate | effective | describe VARIABLE } [-l debug]

Run 'riak help' for more detailed information.
```

Most of these commands are self explanatory, once you know what they mean. `start` and `stop` are simple enough. `restart` means to stop the running node and restart it inside of the same Erlang VM (virtual machine), while `reboot` will take down the Erlang VM and restart everything.

You can print the current running `version`. `ping` will return `pong` if the server is in good shape, otherwise you'll get the *just-similar-enough-to-be-annoying* response `pang` (with an *a*), or a simple `Node X not responding to pings` if it's not running at all.

`chkconfig` is useful if you want to ensure your `etc/riak.conf` is not broken
(that is to say, it's parsable). I mentioned `attach` briefly above, when
we looked into the details of the Ring---it attaches a console to the local
running Riak server so you can execute Riak's Erlang code. `escript` is similar
to `attach`, except you pass in script file of commands you wish to run automatically.

<!--
If you want to build this on a single dev machine, here is a truncated guide.
Download the Riak source code, then run the following:
make deps
make devrel
for i in {1..5}; do dev/dev$i/bin/riak start; done
for i in {1..5}; do dev/dev$i/bin/riak ping; done
for i in {2..5}; do dev/dev$i/bin/riak-admin cluster join riak@AAA.cluster; done
dev/dev1/bin/riak-admin cluster plan
dev/dev1/bin/riak-admin cluster commit
You should now have a 5 node cluster running locally.
-->

<h4>riak-admin</h4>

The `riak-admin` command is the meat operations, the tool you'll use most often. This is where you'll join nodes to the Ring, diagnose issues, check status, and trigger backups.

```bash
Usage: riak-admin { cluster | join | leave | backup | restore | test |
                    reip | js-reload | erl-reload | wait-for-service |
                    ringready | transfers | force-remove | down |
                    cluster-info | member-status | ring-status | vnode-status |
                    aae-status | diag | status | transfer-limit | reformat-indexes |
                    top [-interval N] [-sort reductions|memory|msg_q] [-lines N] |
                    downgrade-objects | security | bucket-type | repair-2i |
                    search | services | ensemble-status }
```

For more information on commands, you can try `man riak-admin`.

A few of these commands are deprecated, and many don't make sense without a
cluster, but some we can look at now.

`status` outputs a list of information about this cluster. It's mostly the same information you can get from getting `/stats` via HTTP, although the coverage of information is not exact (for example, riak-admin status returns `disk`, and `/stats` returns some computed values like `gossip_received`).

```bash
$ riak-admin status
1-minute stats for 'riak@AAA.cluster'
-------------------------------------------
vnode_gets : 0
vnode_gets_total : 2
vnode_puts : 0
vnode_puts_total : 1
vnode_index_reads : 0
vnode_index_reads_total : 0
vnode_index_writes : 0
vnode_index_writes_total : 0
vnode_index_writes_postings : 0
vnode_index_writes_postings_total : 0
vnode_index_deletes : 0
...
```

New JavaScript or Erlang files (as we did in the [developers](#developers) chapter) are not usable by the nodes until they are informed about them by the `js-reload` or `erl-reload` command.

`riak-admin` also provides a little `test` command, so you can perform a read/write cycle
to a node, which I find useful for testing a client's ability to connect, and the node's
ability to write.

Finally, `top` is an analysis command checking the Erlang details of a particular node in
real time. Different processes have different process ids (Pids), use varying amounts of memory,
queue up so many messages at a time (MsgQ), and so on. This is useful for advanced diagnostics,
and is especially useful if you know Erlang or need help from other users, the Riak team, or
Basho.

![Top](../assets/top.png)

<h3>Making a Cluster</h3>

With several solitary nodes running---assuming they are networked and are able to communicate to
each other---launching a cluster is the simplest part.

Executing the `cluster` command will output a descriptive set of commands.

```bash
$ riak-admin cluster
The following commands stage changes to cluster membership. These commands
do not take effect immediately. After staging a set of changes, the staged
plan must be committed to take effect:

 join <node>                  Join node to the cluster containing <node>
 leave                        Have this node leave the cluster and shutdown
 leave <node>                 Have <node> leave the cluster and shutdown

 force-remove <node>          Remove <node> from the cluster without
                              first handing off data. Designed for
                              crashed, unrecoverable nodes

 replace <node1> <node2>      Have <node1> transfer all data to <node2>,
                              and then leave the cluster and shutdown

 force-replace <node1> <node2>  Reassign all partitions owned by <node1>
                              to <node2> without first handing off data,
                              and remove <node1> from the cluster.

Staging commands:
 plan                         Display the staged changes to the cluster
 commit                       Commit the staged changes
 clear                        Clear the staged changes
```

To create a new cluster, you must `join` another node (any will do). Taking a
node out of the cluster uses `leave` or `force-remove`, while swapping out
an old node for a new one uses `replace` or `force-replace`.

I should mention here that using `leave` is the nice way of taking a node
out of commission. However, you don't always get that choice. If a server
happens to explode (or simply smoke ominously), you don't need its approval
to remove it from the cluster, but can instead mark it as `down`.

But before we worry about removing nodes, let's add some first.

```bash
$ riak-admin cluster join riak@AAA.cluster
Success: staged join request for 'riak@BBB.cluster' to 'riak@AAA.cluster'
$ riak-admin cluster join riak@AAA.cluster
Success: staged join request for 'riak@CCC.cluster' to 'riak@AAA.cluster'
```

Once all changes are staged, you must review the cluster `plan`. It will give you
all of the details of the nodes that are joining the cluster, and what it
will look like after each step or *transition*, including the `member-status`,
and how the `transfers` plan to handoff partitions.

Below is a simple plan, but there are cases when Riak requires multiple
transitions to enact all of your requested actions, such as adding and removing
nodes in one stage.

```bash
$ riak-admin cluster plan
=============================== Staged Changes ==============
Action         Nodes(s)
-------------------------------------------------------------
join           'riak@BBB.cluster'
join           'riak@CCC.cluster'
-------------------------------------------------------------


NOTE: Applying these changes will result in 1 cluster transition

#############################################################
                         After cluster transition 1/1
#############################################################

================================= Membership ================
Status     Ring    Pending    Node
-------------------------------------------------------------
valid     100.0%     34.4%    'riak@AAA.cluster'
valid       0.0%     32.8%    'riak@BBB.cluster'
valid       0.0%     32.8%    'riak@CCC.cluster'
-------------------------------------------------------------
Valid:3 / Leaving:0 / Exiting:0 / Joining:0 / Down:0

WARNING: Not all replicas will be on distinct nodes

Transfers resulting from cluster changes: 42
  21 transfers from 'riak@AAA.cluster' to 'riak@CCC.cluster'
  21 transfers from 'riak@AAA.cluster' to 'riak@BBB.cluster'
```

Making changes to cluster membership can be fairly resource intensive,
so Riak defaults to only performing 2 transfers at a time. You can
choose to alter this `transfer-limit` using `riak-admin`, but bear in
mind the higher the number, the greater normal operations will be
impinged.

At this point, if you find a mistake in the plan, you have the chance to `clear` it and try
again. When you are ready, `commit` the cluster to enact the plan.

```bash
$ riak-admin cluster commit
Cluster changes committed
```

Without any data, adding a node to a cluster is a quick operation. However, with large amounts of
data to be transferred to a new node, it can take quite a while before the new node is ready to use.

<h3>Status Options</h3>

To check on a launching node's progress, you can run the `wait-for-service` command. It will
output the status of the service and stop when it's finally up. In this example, we check
the `riak_kv` service.

```bash
$ riak-admin wait-for-service riak_kv riak@CCC.cluster
riak_kv is not up: []
riak_kv is not up: []
riak_kv is up
```

You can get a list of available services with the `services` command.

You can also see if the whole ring is ready to go with `ringready`. If the nodes do not agree
on the state of the ring, it will output `FALSE`, otherwise `TRUE`.

```bash
$ riak-admin ringready
TRUE All nodes agree on the ring ['riak@AAA.cluster','riak@BBB.cluster',
                                  'riak@CCC.cluster']
```

For a more complete view of the status of the nodes in the ring, you can check out `member-status`.

```bash
$ riak-admin member-status
================================= Membership ================
Status     Ring    Pending    Node
-------------------------------------------------------------
valid      34.4%      --      'riak@AAA.cluster'
valid      32.8%      --      'riak@BBB.cluster'
valid      32.8%      --      'riak@CCC.cluster'
-------------------------------------------------------------
Valid:3 / Leaving:0 / Exiting:0 / Joining:0 / Down:0
```

And for more details of any current handoffs or unreachable nodes, try `ring-status`. It
also lists some information from `ringready` and `transfers`. Below I turned off the C
node to show what it might look like.

```bash
$ riak-admin ring-status
================================== Claimant =================
Claimant:  'riak@AAA.cluster'
Status:     up
Ring Ready: true

============================== Ownership Handoff ============
Owner:      dev1 at 127.0.0.1
Next Owner: dev2 at 127.0.0.1

Index: 182687704666362864775460604089535377456991567872
  Waiting on: []
  Complete:   [riak_kv_vnode,riak_pipe_vnode]
...

============================== Unreachable Nodes ============
The following nodes are unreachable: ['riak@CCC.cluster']

WARNING: The cluster state will not converge until all nodes
are up. Once the above nodes come back online, convergence
will continue. If the outages are long-term or permanent, you
can either mark the nodes as down (riak-admin down NODE) or
forcibly remove the nodes from the cluster (riak-admin
force-remove NODE) to allow the remaining nodes to settle.
```

If all of the above information options about your nodes weren't enough, you can
list the status of each vnode per node, via `vnode-status`. It'll show each
vnode by its partition number, give any status information, and a count of each
vnode's keys. Finally, you'll get to see each vnode's backend type---something I'll
cover in the next section.

```bash
$ riak-admin vnode-status
Vnode status information
-------------------------------------------

VNode: 0
Backend: riak_kv_bitcask_backend
Status:
[{key_count,0},{status,[]}]

VNode: 91343852333181432387730302044767688728495783936
Backend: riak_kv_bitcask_backend
Status:
[{key_count,0},{status,[]}]

VNode: 182687704666362864775460604089535377456991567872
Backend: riak_kv_bitcask_backend
Status:
[{key_count,0},{status,[]}]

VNode: 274031556999544297163190906134303066185487351808
Backend: riak_kv_bitcask_backend
Status:
[{key_count,0},{status,[]}]

VNode: 365375409332725729550921208179070754913983135744
Backend: riak_kv_bitcask_backend
Status:
[{key_count,0},{status,[]}]
...
```

Some commands we did not cover are either deprecated in favor of their `cluster`
equivalents (`join`, `leave`, `force-remove`, `replace`, `force-replace`), or
flagged for future removal `reip` (use `cluster replace`).

I know this was a lot to digest, and probably pretty dry. Walking through command
line tools usually is. There are plenty of details behind many of the `riak-admin`
commands, too numerous to cover in such a short book. I encourage you to toy around
with them on your own installation.


## New in Riak 2.0

Riak has been a project since 2009. And in that time, it has undergone a few evolutions, largely technical improvements, such as more reliability and data safety mechanisms like active anti-entropy.

Riak 2.0 was not a rewrite, but rather, a huge shift in how developers who use Riak interact with it. While Basho continued to make backend improvements (such as better cluster metadata) and simplified using existing options (`repair-2i` is now a `riak-admin` command, rather than code you must execute), the biggest changes are immediately obvious to developers. But many of those improvements are also made easier for operators to administrate. So here are a few highlights of the new 2.0 interface options.


<h3>Bucket Types</h3>

A centerpiece of the new Riak 2.0 features is the addition of a higher-level bucket configuration namespace called *bucket types*. We discussed the general idea of bucket types in the previous chapters, but one major departure from standard buckets is that they are created via the command-line. This means that operators with server access can manage the default properties that all buckets of a given bucket type inherit.

Bucket types have a set of tools for creating, managing and activating them.

```bash
$ riak-admin bucket-type
Usage: riak-admin bucket-type <command>

The follow commands can be used to manage bucket types for the cluster:

   list                           List all bucket types and their activation status
   status <type>                  Display the status and properties of a type
   activate <type>                Activate a type
   create <type> <json>           Create or modify a type before activation
   update <type> <json>           Update a type after activation
```

It's rather straightforward to `create` a bucket type. The JSON string accepted after the bucket type name are any valid bucket propertied. Any bucket that uses this type will inherit those properties. For example, say that you wanted to create a bucket type whose n_val was always 1 (rather than the default 3), named unsafe.

```bash
$ riak-admin bucket-type create unsafe '{"props":{"n_val":1}}'
```

Once you create the bucket type, it's a good idea to check the `status`, and ensure the properties are what you meant to set.

```bash
$ riak-admin bucket-type status unsafe
```

A bucket type is not active until you propgate it through the system by calling the `activate` command.

```bash
$ riak-admin bucket-type activate unsafe
```

If something is wrong with the type's properties, you can always `update` it.

```bash
$ riak-admin bucket-type update unsafe '{"props":{"n_val":1}}'
```

You can update a bucket type after it's actived. All of the changes that you make to the type will be inherited by every bucket under that type.

Of course, you can always get a `list` of the current bucket types in the system. The list will also say whether the bucket type is activated or not.

Other than that, there's nothing interesting about bucket types from an operations point of view, per se. Sure, there are some cool internal mechanisms at work, such as propogated metadata via a path laied out by a plum-tree and causally tracked by dotted version vectors. But that's only code plumbing. What's most interesting about bucket types are the new features you can take advantage of: datatypes, strong consistency, and search.


<h3>Datatypes</h3>

Datatypes are useful for engineers, since they no longer have to consider the complexity of manual conflict merges that can occur in fault situations. It can also be less stress on the system, since larger objects need only communicate their changes, rather than reinsert the full object.

Riak 2.0 supports four datatypes: *map*, *set*, *counter*, *flag*. You create a bucket type with a single datatype. It's not required, but often good form to name the bucket type after the datatype you're setting.

```bash
$ riak-admin bucket-type create maps '{"props":{"datatype":"map"}}'
$ riak-admin bucket-type create sets '{"props":{"datatype":"set"}}'
$ riak-admin bucket-type create counters '{"props":{"datatype":"counter"}}'
$ riak-admin bucket-type create flags '{"props":{"datatype":"flag"}}'
```

Once a bucket type is created with the given datatype, you need only active it. Developers can then use this datatype like we saw in the previous chapter, but hopefully this example makes clear the suggestion of naming bucket types after their datatype.

```bash
curl -XPUT "$RIAK/types/counters/buckets/visitors/keys/index_page" \
  -H "Content-Type:application/json"
  -d 1
```


<h3>Strong Consistency</h3>

Strong consistency (SC) is the opposite of everything that Riak stands for. Where Riak is all about high availability in the face of network or server errors, strong consistency is about safety over liveness. Either the network and servers are working perfectly, or the reads and writes fail. So why on earth would we ever want to provide SC and give up HA? Because you asked for. Really.

There are some very good use-cases for strong consistency. For example, when a user is completing a purchase, you might want to ensure that the system is always in a consistent state, or fail the purchase. Communicating that a purchase was made when it in fact was not, is not a good user experience. The opposite is even worse.

While Riak will continue to be primarily an HA system, there are cases where SC is useful, and developers should be allowed to choose without having to install an entirely new database. So all you need to do is activate it in `riak.conf`.

```bash
strong_consistency = on
```

One thing to note is, although we generally recommend you have five nodes in a Riak cluster, it's not a hard requirement. Strong consistency, however, requires three nodes. It will not operate with fewer.

Once our SC systme is active, you'll lean on bucket types again. Only buckets that live under a bucket type setup for strong consistency will be strongly consistent. This means that you can have some buckets HA, other SC, in the same database. Let's call our SC bucket type `strong`.

```bash
$ riak-admin bucket-type create strong '{"props":{"consistent":true}}'
$ riak-admin bucket-type activate strong
```

That's all the operator should need to do. The developers can use the `strong` bucket similarly to other buckets.

```bash
curl -XPUT "$RIAK/types/strong/buckets/purchases/keys/jane" \
  -d '{"action":"buy"}'
```

Jane's purchases will either succeed or fail. It will not be eventually consistent. If it fails, of course, she can try again.

What if your system is having problems with strong consistency? Basho has provided a command to interrogate the current status of the subsystem responsible for SC named ensemble. You can check it out by running `ensemble-status`.

```bash
$ riak-admin ensemble-status
```

It will give you the best information it has as to the state of the system. For example, if you didn't enable `strong_consistency` in every node's `riak.conf`, you might see this.

```bash
============================== Consensus System ===============================
Enabled:     false
Active:      false
Ring Ready:  true
Validation:  strong (trusted majority required)
Metadata:    best-effort replication (asynchronous)

Note: The consensus subsystem is not enabled.

================================== Ensembles ==================================
There are no active ensembles.
```

In the common case when all is working, you should see an output similar to the following:

```bash
============================== Consensus System ===============================
Enabled:     true
Active:      true
Ring Ready:  true
Validation:  strong (trusted majority required)
Metadata:    best-effort replication (asynchronous)

================================== Ensembles ==================================
 Ensemble     Quorum        Nodes      Leader
-------------------------------------------------------------------------------
   root       4 / 4         4 / 4      riak@riak1
    2         3 / 3         3 / 3      riak@riak2
    3         3 / 3         3 / 3      riak@riak4
    4         3 / 3         3 / 3      riak@riak1
    5         3 / 3         3 / 3      riak@riak2
    6         3 / 3         3 / 3      riak@riak2
    7         3 / 3         3 / 3      riak@riak4
    8         3 / 3         3 / 3      riak@riak4
```

This output tells you that the consensus system is both enabled and active, as well as lists details about all known consensus groups (ensembles).

There is plenty more information about the details of strong consistency in the online docs.


<h3>Search 2.0</h3>

From an operations standpoint, search is deceptively simple. Functionally, there isn't much you should need to do with search, other than activate it in `riak.conf`.

```bash
search = on
```

However, looks are deceiving. Under the covers, Riak Search 2.0 actually runs the search index software called Solr. Solr runs as a Java service. All of the code required to convert an object that you insert into a document that Solr can recognize (by a module called an *Extractor*) is Erlang, and so is the code which keeps the Riak objects and Solr indexes in sync through faults (via AAE), as well as all of the interfaces, security, stats, and query distribution. But since Solr is Java, we have to manage the JVM.

If you don't have much experience running Java code, let me distill most problems for you: you need more memory. Solr is a memory hog, easily requiring a minimum of 2 GiB of RAM dedicated only to the Solr service itself. This is in addition to the 4 GiB of RAM minimum that Basho recommends per node. So, according to math, you need a minimum of 6 GiB of RAM to run Riak Search. But we're not quite through yet.

The most important setting in Riak Search are the JVM options. These options are passed into the JVM command-line when the Solr service is started, and most of the options chosen are excellent defaults. I recommend not getting to hung up on tweaking those, with one notable exception.

```bash
## The options to pass to the Solr JVM.  Non-standard options,
## i.e. -XX, may not be portable across JVM implementations.
## E.g. -XX:+UseCompressedStrings
## 
## Default: -d64 -Xms1g -Xmx1g -XX:+UseStringCache -XX:+UseCompressedOops
## 
## Acceptable values:
##   - text
search.solr.jvm_options = -d64 -Xms1g -Xmx1g -XX:+UseStringCache -XX:+UseCompressedOops
```

In the default setting, Riak gives 1 GiB of RAM to the Solr JVM heap. This is fine for small clusters with small, lightly used indexes. You may want to bump those heap values up---the two args of note are: `-Xms1g` (minimum size 1 gigabyte) and `-Xmx1g` (maximum size 1 gigabyte). Push those to 2 or 4 (or even higher) and you should be fine.

In the interested of completeness, Riak also communicates to Solr internally through a port, which you can configure (along with an option JMX port). You should never need to connect to this port yourself.

```bash
## The port number which Solr binds to.
## NOTE: Binds on every interface.
## 
## Default: 8093
## 
## Acceptable values:
##   - an integer
search.solr.port = 8093

## The port number which Solr JMX binds to.
## NOTE: Binds on every interface.
## 
## Default: 8985
## 
## Acceptable values:
##   - an integer
search.solr.jmx_port = 8985
```

There's generally no great reason to alter these defaults, but they're there if you need them.

I should also note that, thanks to fancy bucket types, you can associate a bucket type with a search index. You associate buckets (or types) with indexes by adding a search_index property, with the name of a Solr index. Like so, assuming that you've created a solr index named `my_index`:

```bash
$ riak-admin bucket-type create indexed '{"props":{"search_index":"my_index"}}'
$ riak-admin bucket-type activate indexed
```

Now, any object that a developer puts into yokozuna under that bucket type will be indexed.

There's a lot more to search than we can possibly cover here without making it a book in its own right. You may want to checkout the following documentation in docs.basho.com for more details.

* [Riak Search Settings](http://docs.basho.com/riak/latest/ops/advanced/configs/search/)
* [Using Search](http://docs.basho.com/riak/latest/dev/using/search/)
* [Search Details](http://docs.basho.com/riak/latest/dev/advanced/search/)
* [Search Schema](http://docs.basho.com/riak/latest/dev/advanced/search-schema/)
* [Upgrading Search from 1.x to 2.x](http://docs.basho.com/riak/latest/ops/advanced/upgrading-search-2/)

<h3>Security</h3>

Riak has lived quite well in the first five years of its life without security. So why did Basho add it now? With the kind of security you get through a firewall, you can only get course-grained security. Someone can either access the system or not, with a few restrictions, depending on how clever you write your firewall rules.

With the addition of Security, Riak now supports authentication (identifying a user) and authorization (restricting user access to a subset of commands) of users and groups. Access can also be restricted to a known set of sources. The security design was inspired by the full-featured rules in PostgreSQL.

Before you decide to enable security, you should consider this checklist in advance.

1. If you use security, you must upgrade to Riak Search 2.0. The old Search will not work (neither will the deprecated Link Walking). Check any Erlang MapReduce code for invocations of Riak modules other than `riak_kv_mapreduce`. Enabling security will prevent those from succeeding unless those modules are available via `add_path`
2. Make sure that your application code is using the most recent drivers
3. Define users and (optionally) groups, and their sources
4. Grant the necessary permissions to each user/group

With that out of the way, you can `enable` security with a command-line option (you can `disable` security as well). You can optionally check the `status` of security at any time.

```bash
$ riak-admin security enable
$ riak-admin security status
Enabled
```

Adding users is as easy as the `add-user` command. A username is required, and can be followed with any key/value pairs. `password` and `groups` are special cases, but everything is free form. You can alter existing users as well. Users can belong to any number of groups, and inherit a union of all group settings.


```bash
$ riak-admin security add-group mascots type=mascot
$ riak-admin security add-user bashoman password=Test1234
$ riak-admin security alter-user bashoman groups=mascots
```

You can see the list of all users via `print-users`, or all groups via `print-groups`.

```bash
$ riak-admin security print-users
+----------+----------+----------------------+---------------------+
| username |  groups  |       password       |       options       |
+----------+----------+----------------------+---------------------+
| bashoman | mascots  |983e8ae1421574b8733824| [{"type","mascot"}] |
+----------+----------+----------------------+---------------------+
```

Creating user and groups is nice and all, but the real reason for doing this is so we can distinguish authorization between different users and groups. You `grant` or `revoke` `permissions` to users and groups by way of the command line, of course. You can grant/revoke a permission to anything, a certain bucket type, or a specific bucket.

```bash
$ riak-admin security grant riak_kv.get on any to all
$ riak-admin security grant riak_kv.delete on any to admin
$ riak-admin security grant search.query on index people to bashoman
$ riak-admin security revoke riak_kv.delete on any to bad_admin
```

There are many kinds of permissions, one for every major operation or set of operations in Riak. It's worth noting that you can't add search permissions without search enabled.

* __riak\_kv.get__ --- Retrieve objects
* __riak\_kv.put__ --- Create or update objects
* __riak\_kv.delete__  --- Delete objects
* __riak\_kv.index__ --- Index objects using secondary indexes (2i)
* __riak\_kv.list\_keys__ --- List all of the keys in a bucket
* __riak\_kv.list\_buckets__  --- List all buckets
* __riak\_kv.mapreduce__ --- Can run MapReduce jobs
* __riak\_core.get\_bucket__  --- Retrieve the props associated with a bucket
* __riak\_core.set\_bucket__  --- Modify the props associated with a bucket
* __riak\_core.get\_bucket\_type__ --- Retrieve the set of props associated with a bucket type
* __riak\_core.set\_bucket\_type__ --- Modify the set of props associated with a bucket type
* __search.admin__  --- The ability to perform search admin-related tasks, like creating and deleting indexes
* __search.query__  --- The ability to query an index

Finally, with our group and user created, and given access to a subset of permissions, we have one more major item to deal with. We want to be able to filter connection from specific sources.

```bash
$ riak-admin security add-source all|<users> <CIDR> <source> [<option>=<value>[...]]
```

This is powerful security, since Riak will only accept connections that pass specific criteria, such as a certain certificate or password, or from a specific IP address. Here we trust any connection that's initiated locally.

```bash
$ riak-admin security add-source all 127.0.0.1/32 trust
```

There's plenty more you can learn about in the [Authentication and Authorization](http://docs.basho.com/riak/2.0.0/ops/running/authz/) online documentation.

<h3>Dynamic Ring Resizing</h3>

As of Riak 2.0, you can now resize the number of vnodes in the ring. The number of vnodes must be a power of 2 (eg. `64`, `256`, `1024`). It's a very heavyweight operation, and should not be a replacement for proper growth planning (aiming for `8` to `16` vnodes per node). However, if you experience greater than expected growth, this is quite a bit easier than transfering your entire dataset manually to a larger cluster. It just continues the Riak philosophy of easy operations, and no downtime!


```bash
$ riak-admin cluster resize-ring 128
Success: staged resize ring request with new size: 128
```

Then commit the cluster plan in required two phase plan/commit steps.

```bash
$ riak-admin cluster plan
$ riak-admin cluster commit
```

It can take quite a while for ring resizing to complete. You're effectively moving around half (or more) of the cluster's values around to new partitions. You can track the status of this resize with the a couple commands. The `ring-status` command we've seen before, which will show you all of the changes that are queued up or in progress.

```bash
$ riak-admin ring-status
```

If you want to see a different view of specifically handoff transfers, there's the `transfers` command.

```bash
$ riak-admin transfers
'riak@AAA.cluster' waiting to handoff 3 partitions
'riak@BBB.cluster' waiting to handoff 1 partitions
'riak@CCC.cluster' waiting to handoff 1 partitions
'riak@DDD.cluster' waiting to handoff 2 partitions

Active Transfers:

transfer type: resize_transfer
vnode type: riak_kv_vnode
partition: 1438665674247607560106752257205091097473808596992
started: 2014-01-20 21:03:53 [1.14 min ago]
last update: 2014-01-20 21:05:01 [1.21 s ago]
total size: 111676327 bytes
objects transferred: 122598

                         1818 Objs/s                          
     riak@AAA.cluster        =======>       riak@DDD.cluster      
        |=========================                  |  58%    
                         950.38 KB/s                          
```

If the resize activity is taking too much time, or consuming too many resources, you can alter the `handoff_concurrency` limit on the fly. This limit is the number of vnodes per physical node that are allowed to perform handoff at once, and defaults to 2. You can change the setting in the entire cluster, or per node. Say you want to change transfer up to 4 vnodes at a time.

```bash
riak-admin transfer-limit 4
```

Or for a single node.

```bash
$ riak-admin transfer-limit riak@AAA.cluster 4
```

Ring resizing will be complete once you get this message from `riak-admin transfers`:

```bash
No transfers active
```

What if something goes wrong? What if you made a mistake? No problem, you can always abort the ring resize command.

```bash
$ riak-admin cluster resize-ring abort
$ riak-admin cluster plan
$ riak-admin cluster commit
```

Any queued handoffs will be stopped. But any completed handoffs may have to be transfered back. Easy-peasy!



## How Riak is Built

![Tech Stack](../assets/riak-stack.svg)

It's difficult to label Riak as a single project. It's probably more correct to think of
Riak as the center of gravity for a whole system of projects. As we've covered
before, Riak is built on Erlang, but that's not the whole story. It's more correct
to say Riak is fundamentally Erlang, with some pluggable native C code components
(like leveldb), Java (Yokozuna), and even JavaScript (for MapReduce or commit hooks).

The way Riak stacks technologies is a good thing to keep in mind, in order to make
sense of how to configure it properly.

<h3>Erlang</h3>

![Tech Stack Erlang](../assets/decor/riak-stack-erlang.png)

When you fire up a Riak node, it also starts up an Erlang VM (virtual machine) to run
and manage Riak's processes. These include vnodes, process messages, gossips, resource
management and more. The Erlang operating system process is found as a `beam.smp`
command with many, many arguments.

These arguments are configured through the `etc/riak.conf` file. There are a few
settings you should pay special attention to.

```bash
$ ps -o command | grep beam
/riak/erts-5.9.1/bin/beam.smp \
-K true \
-A 64 \
-W w -- \
-root /riak \
-progname riak -- \
-home /Users/ericredmond -- \
-boot /riak/releases/2.0.0/riak \
-embedded \
-config /riak/data/generated.configs/app.2014.08.15.12.38.45.config \
-pa ./lib/basho-patches \
-name riak@AAA.cluster \
-setcookie testing123 -- \
console
```

The `name` setting is the name of the current Riak node. Every node in your cluster
needs a different name. It should have the IP address or dns name of the server
this node runs on, and optionally a different prefix---though some people just like
to name it *riak* for simplicity (eg: `riak@node15.myhost`).

The `setcookie` parameter is a setting for Erlang to perform inter-process
communication (IPC) across nodes. Every node in the cluster must have the same
cookie name. I recommend you change the name from `riak` to something a little
less likely to accidentally conflict, like `hihohihoitsofftoworkwego`.

My `riak.conf` sets it's node name and cookie like this:

```bash
## Name of the Erlang node
## 
## Default: riak@127.0.0.1
## 
## Acceptable values:
##   - text
nodename = riak@AAA.cluster

## Cookie for distributed node communication.  All nodes in the
## same cluster should use the same cookie or they will not be able to
## communicate.
## 
## Default: riak
## 
## Acceptable values:
##   - text
distributed_cookie = testing123
```

Continuing down the `riak.conf` file are more Erlang settings, some environment
variables that are set up for the process (prefixed by `-env`), followed by
some optional SSL encryption settings.

<h3>riak_core</h3>

![Tech Stack Core](../assets/decor/riak-stack-core.png)

If any single component deserves the title of "Riak proper", it would
be *Riak Core*. Core shares responsibility with projects built atop it
for managing the partitioned keyspace, launching and supervising
vnodes, preference list building, hinted handoff, and things that
aren't related specifically to client interfaces, handling requests,
or storage.

Riak Core, like any project, has some hard-coded values (for example, how
protocol buffer messages are encoded in binary). However, many values
can be modified to fit your use case. The majority of this configuration
occurs under `riak.conf`. This file is Erlang code, so commented lines
begin with a `%` character.

The `riak_core` configuration section allows you to change the options in
this project. This handles basic settings, like files/directories where
values are stored or to be written to, the number of partitions/vnodes
in the cluster (`ring_size`), and several port options.

```bash
## Default location of ringstate
ring.state_dir = $(platform_data_dir)/ring

## Number of partitions in the cluster (only valid when first
## creating the cluster). Must be a power of 2, minimum 8 and maximum
## 1024.
## 
## Default: 64
## 
## Acceptable values:
##   - an integer
ring_size = 8

## listener.http.<name> is an IP address and TCP port that the Riak
## HTTP interface will bind.
## 
## Default: 127.0.0.1:8098
## 
## Acceptable values:
##   - an IP/port pair, e.g. 127.0.0.1:8098
listener.http.internal = 0.0.0.0:8098

## listener.protobuf.<name> is an IP address and TCP port that the Riak
## Protocol Buffers interface will bind.
## 
## Default: 127.0.0.1:8087
## 
## Acceptable values:
##   - an IP/port pair, e.g. 127.0.0.1:8087
listener.protobuf.internal = 0.0.0.0:8087

## listener.https.<name> is an IP address and TCP port that the Riak
## HTTPS interface will bind.
## 
## Acceptable values:
##   - an IP/port pair, e.g. 127.0.0.1:8069
## listener.https.internal = 127.0.0.1:8069

## riak handoff_port is the TCP port that Riak uses for
## intra-cluster data handoff.
## handoff.port = 8099

## Platform-specific installation paths
## platform_bin_dir = ./bin
## platform_data_dir = ./data
## platform_etc_dir = ./etc
## platform_lib_dir = ./lib
## platform_log_dir = ./log
```

<h3>riak_kv</h3>

![Tech Stack KV](../assets/decor/riak-stack-kv.png)

Riak KV is a key/value implementation of Riak Core. This is where the
magic happens, such as handling requests and coordinating them for
redundancy and read repair. It's what makes Riak a KV store rather
than something else like a Cassandra-style columnar data store.

<!-- When configuring KV, you may scratch your head about about when a setting belongs
under `riak_kv` versus `riak_core`. For example, if `http` is under core, why
is raw_name under riak. -->

KV is so integral to the function of Riak, that it's hardly worth going over
its settings as an independent topic. Many of of the values you set in other
subsystems are used by KV in some capacity. So let's move on.

<h3>yokozuna</h3>

![Tech Stack Yokozuna](../assets/decor/riak-stack-yokozuna.png)

Yokozuna is the newest addition to the Riak ecosystem. It's an integration of
the distributed Solr search engine into Riak, and provides some extensions
for extracting, indexing, and tagging documents. The Solr server runs its
own HTTP interface, and though your Riak users should never have to access
it, you can choose which `solr_port` will be used.

```bash
search = on
search.solr_port = 8093
```

<h3>bitcask, eleveldb, memory, multi</h3>

Several modern databases have swappable backends, and Riak is no different in that
respect. Riak currently supports three different storage engines: *Bitcask*,
*eLevelDB*, and *Memory* --- and one hybrid called *Multi*.

Using a backend is simply a matter of setting the `storage_backend` with one of the following values.

- `bitcask` - The catchall Riak backend. If you don't have a compelling reason to *not* use it, this is my suggestion.
- `leveldb` - A Riak-friendly backend which uses a very customized version of Google's leveldb. This is necessary if you have too many keys to fit into memory, or wish to use 2i.
- `memory` - A main-memory backend, with time-to-live (TTL). Meant for transient data.
- `multi` - Any of the above backends, chosen on a per-bucket basis.


```bash
## Specifies the storage engine used for Riak's key-value data
## and secondary indexes (if supported).
## 
## Default: bitcask
## 
## Acceptable values:
##   - one of: bitcask, leveldb, memory, multi
storage_backend = memory
```

Then, with the exception of Multi, each memory configuration is under one of
the following options. TTL (time to live) is great and useful, but note, that
it's only useful if you're using Riak as a strict KV store. The backend won't
communicate to other systems (such as Search) that the value has timed out.

```bash
## Memory Config
memory.max_memory = 4GB
memory.ttl = 86400  # 1 Day in seconds
```

Bitcask is a simple soul. It's the backend of choice, and generally the most complex setting you might want to toy with is how bitcask flushes data to disk.

```bash
## A path under which bitcask data files will be stored.
## 
## Default: $(platform_data_dir)/bitcask
## 
## Acceptable values:
##   - the path to a directory
bitcask.data_root = $(platform_data_dir)/bitcask

## Configure how Bitcask writes data to disk.
## erlang: Erlang's built-in file API
## nif: Direct calls to the POSIX C API
## The NIF mode provides higher throughput for certain
## workloads, but has the potential to negatively impact
## the Erlang VM, leading to higher worst-case latencies
## and possible throughput collapse.
## 
## Default: erlang
## 
## Acceptable values:
##   - one of: erlang, nif
bitcask.io_mode = erlang
```

However, there are many, many more levers and knobs to pull and twist.

```bash
## Bitcask Config
bitcask.data_root = $(platform_data_dir)/bitcask
bitcask.expiry = off
bitcask.expiry.grace_time = 0
bitcask.fold.max_age = unlimited
bitcask.fold.max_puts = 0
bitcask.hintfile_checksums = strict
bitcask.io_mode = erlang
bitcask.max_file_size = 2GB
bitcask.max_merge_size = 100GB
bitcask.merge.policy = always
bitcask.merge.thresholds.dead_bytes = 128MB
bitcask.merge.thresholds.fragmentation = 40
bitcask.merge.thresholds.small_file = 10MB
bitcask.merge.triggers.dead_bytes = 512MB
bitcask.merge.triggers.fragmentation = 60
bitcask.merge.window.end = 23
bitcask.merge.window.start = 0
bitcask.merge_check_interval = 3m
bitcask.merge_check_jitter = 30%
bitcask.open_timeout = 4s
bitcask.sync.strategy = none
```

There are many configuration values for leveldb. But most of the time, you're best served to leave them alone. The only value you may ever want to play with is the maximum_memory percent, which defines the most system memory that leveldb will ever use.

```bash
## This parameter defines the percentage of total server memory
## to assign to LevelDB. LevelDB will dynamically adjust its internal
## cache sizes to stay within this size.  The memory size can
## alternately be assigned as a byte count via leveldb.maximum_memory
## instead.
## 
## Default: 70
## 
## Acceptable values:
##   - an integer
leveldb.maximum_memory.percent = 70
```

But, if you really want to peek into leveldb's spectrum of choices:

```bash
# LevelDB Config
leveldb.block.restart_interval = 16
leveldb.block.size = 4KB
leveldb.block.size_steps = 16
leveldb.block_cache_threshold = 32MB
leveldb.bloomfilter = on
leveldb.compaction.trigger.tombstone_count = 1000
leveldb.compression = on
leveldb.data_root = $(platform_data_dir)/leveldb
leveldb.fadvise_willneed = false
leveldb.limited_developer_mem = on
leveldb.sync_on_write = off
leveldb.threads = 71
leveldb.tiered = off
leveldb.verify_checksums = on
leveldb.verify_compaction = on
leveldb.write_buffer_size_max = 60MB
leveldb.write_buffer_size_min = 30MB
```

![Tech Stack Backend](../assets/decor/riak-stack-backend.png)

With the Multi backend, you can even choose different backends
for different buckets. This can make sense, as one bucket may hold
user information that you wish to index (use eleveldb), while another
bucket holds volatile session information that you may prefer to simply
remain resident (use memory).

You can set up a multi backend by adding/using an `advanced.config`
file, which lives in the riak `etc` directory alongside `riak.conf`.

```bash
%% Riak KV config
{riak_kv, [
  %% Storage_backend specifies the Erlang module defining
  %% the storage mechanism that will be used on this node.
  {storage_backend = riak_kv_multi_backend},

  %% Choose one of the names you defined below
  {multi_backend_default, <<"bitcask_multi">>},

  {multi_backend, [
    %% Heres where you set the individual backends
    {<<"bitcask_multi">>,  riak_kv_bitcask_backend, [
      %% bitcask configuration
      {config1, ConfigValue1},
      {config2, ConfigValue2}
    ]},
    {<<"memory_multi">>,   riak_kv_memory_backend, [
      %% memory configuration
      {max_memory, 8192}   %% 8GB
    ]}
  ]},
]}.
```

You can put the `memory_multi` configured above to the `session_data` bucket
by just setting its `backend` property.

```bash
$ curl -XPUT $RIAK/types/default/buckets/session_data/props \
  -H "Content-Type: application/json" \
  -d '{"props":{"backend":"memory_multi"}}'
```

<h3>riak_api</h3>

![Tech Stack API](../assets/decor/riak-stack-api.png)

So far, all of the components we've seen have been inside the Riak
house. The API is the front door. *In a perfect world*, the API would
manage two implementations: HTTP and Protocol buffers (PB), an
efficient binary protocol framework designed by Google.

But because they are not yet separated, only PB is configured under `riak_api`,
while HTTP still remains under KV.

In any case, Riak API represents the client facing aspect of Riak. Implementations
handle how data is encoded and transferred, and this project handles the services
for presenting those interfaces, managing connections, providing entry points.


```bash
## listener.protobuf.<name> is an IP address and TCP port that the Riak
## Protocol Buffers interface will bind.
## 
## Default: 127.0.0.1:8087
## 
## Acceptable values:
##   - an IP/port pair, e.g. 127.0.0.1:8087
listener.protobuf.internal = 0.0.0.0:8087

## The maximum length to which the queue of pending connections
## may grow. If set, it must be an integer > 0. If you anticipate a
## huge number of connections being initialized *simultaneously*, set
## this number higher.
## 
## Default: 128
## 
## Acceptable values:
##   - an integer
protobuf.backlog = 128
```

<h3>Other projects</h3>

Other projects add depth to Riak but aren't strictly necessary. Two of
these projects are lager, for logging, and riak_sysmon, for
monitoring. Both have reasonable defaults and well-documented
settings.

* https://github.com/basho/lager
* https://github.com/basho/riak_sysmon

Most of the time, you'll just use lager's default logging settings.
However, you can configure lager via `riak.conf`.

```bash
## Where to emit the default log messages (typically at 'info'
## severity):
## off: disabled
## file: the file specified by log.console.file
## console: to standard output (seen when using `riak attach-direct`)
## both: log.console.file and standard out.
## 
## Default: both
## 
## Acceptable values:
##   - one of: off, file, console, both
log.console = both

## The severity level of the console log, default is 'info'.
## 
## Default: info
## 
## Acceptable values:
##   - one of: debug, info, warning, error
log.console.level = info

## When 'log.console' is set to 'file' or 'both', the file where
## console messages will be logged.
## 
## Default: $(platform_log_dir)/console.log
## 
## Acceptable values:
##   - the path to a file
log.console.file = $(platform_log_dir)/console.log

## The file where error messages will be logged.
## 
## Default: $(platform_log_dir)/error.log
## 
## Acceptable values:
##   - the path to a file
log.error.file = $(platform_log_dir)/error.log

## When set to 'on', enables log output to syslog.
## 
## Default: off
## 
## Acceptable values:
##   - on or off
log.syslog = off

## Whether to enable the crash log.
## 
## Default: on
## 
## Acceptable values:
##   - on or off
log.crash = on

## If the crash log is enabled, the file where its messages will
## be written.
## 
## Default: $(platform_log_dir)/crash.log
## 
## Acceptable values:
##   - the path to a file
log.crash.file = $(platform_log_dir)/crash.log

## Maximum size in bytes of individual messages in the crash log
## 
## Default: 64KB
## 
## Acceptable values:
##   - a byte size with units, e.g. 10GB
log.crash.maximum_message_size = 64KB

## Maximum size of the crash log in bytes, before it is rotated
## 
## Default: 10MB
## 
## Acceptable values:
##   - a byte size with units, e.g. 10GB
log.crash.size = 10MB

## The schedule on which to rotate the crash log.  For more
## information see:
## https://github.com/basho/lager/blob/master/README.md#internal-log-rotation
## 
## Default: $D0
## 
## Acceptable values:
##   - text
log.crash.rotation = $D0

## The number of rotated crash logs to keep. When set to
## 'current', only the current open log file is kept.
## 
## Default: 5
## 
## Acceptable values:
##   - an integer
##   - the text "current"
log.crash.rotation.keep = 5
```

If you want to set custom log messages layouts, you can set them
in `advanced.config`.

```bash
%% Lager Config
{lager, [
  %% What handlers to install with what arguments
  %% If you wish to disable rotation, you can either set
  %% the size to 0 and the rotation time to "", or instead
  %% specify 2-tuple that only consists of {Logfile, Level}.
  {handlers, [
    {lager_file_backend, [
      {"./log/error.log", error, 10485760, "$D0", 5},
      {"./log/console.log", info, 10485760, "$D0", 5}
    ]}
  ]},
]}.
```

Finally, there's a system monitor (sysmon) that tracks the Erlang VM. It's usually best to just keep these default values as-is.

```bash
runtime_health.thresholds.busy_ports = 2
runtime_health.thresholds.busy_processes = 30
runtime_health.triggers.distribution_port = on
runtime_health.triggers.port = on
runtime_health.triggers.process.garbage_collection = off
runtime_health.triggers.process.heap_size = 160444000
```


## Tools

<h3>Riaknostic</h3>

You may recall that we skipped the `diag` command while looking through
`riak-admin`, but it's time to circle back around.

[Riaknostic](http://riaknostic.basho.com/) is a diagnostic tool
for Riak, meant to run a suite of checks against an installation to
discover potential problems. If it finds any, it also recommends
potential resolutions.

Riaknostic exists separately from the core project but as of Riak 1.3
is included and installed with the standard database packages.

```bash
$ riak-admin diag --list
Available diagnostic checks:

  disk                 Data directory permissions and atime
  dumps                Find crash dumps
  memory_use           Measure memory usage
  nodes_connected      Cluster node liveness
  ring_membership      Cluster membership validity
  ring_preflists       Check ring satisfies n_val
  ring_size            Ring size valid
  search               Check whether search is enabled on all nodes
```

I'm a bit concerned that my disk might be slow, so I ran the `disk` diagnostic.

```bash
$ riak-admin diag disk
21:52:47.353 [notice] Data directory /riak/data/bitcask is\
not mounted with 'noatime'. Please remount its disk with the\
'noatime' flag to improve performance.
```

Riaknostic returns an analysis and suggestion for improvement. Had my disk
configuration been ok, the command would have returned nothing.


<h3>Riak Control</h3>

The last tool we'll look at is the aptly named
[Riak Control](http://docs.basho.com/riak/latest/ops/advanced/riak-control/).
It's a web application for managing Riak clusters, watching, and drilling down
into the details of your nodes to get a comprehensive view of the system. That's the
idea, anyway. It's forever a work in progress, and it does not yet have parity with
all of the command-line tools we've looked at. However, it's great for quick
checkups and routing configuration changes.

Riak Control is shipped with Riak as of version 1.1, but turned off by
default. You can enable it on one of your servers by editing
`riak.conf` and restarting the node.

If you're going to turn it on in production, do so carefully: you're
opening up your cluster to remote administration using a password that
sadly must be stored in plain text in the configuration file.

The first step is to enable SSL and HTTPS in the `riak_core` section
of `riak.conf`.  You can just uncomment these lines, set the `https`
port to a reasonable value like `8069`, and point the `certfile` and
`keyfile` to your SSL certificate. If you have an intermediate
authority, add the `cacertfile` too.

```bash
## listener.https.<name> is an IP address and TCP port that the Riak
## HTTPS interface will bind.
## 
## Acceptable values:
##   - an IP/port pair, e.g. 127.0.0.1:8069
listener.https.internal = 127.0.0.1:8069

## Default cert location for https can be overridden
## with the ssl config variable, for example:
## 
## Acceptable values:
##   - the path to a file
ssl.certfile = $(platform_etc_dir)/cert.pem

## Default key location for https can be overridden with the ssl
## config variable, for example:
## 
## Acceptable values:
##   - the path to a file
ssl.keyfile = $(platform_etc_dir)/key.pem

## Default signing authority location for https can be overridden
## with the ssl config variable, for example:
## 
## Acceptable values:
##   - the path to a file
ssl.cacertfile = $(platform_etc_dir)/cacertfile.pem
```

Then, you'll have to `enable` Riak Control in your `riak.conf`, and add a user.
Note that the user password is plain text. Yeah it sucks, so be careful to not
open your Control web access to the rest of the world, or you risk giving away
the keys to the kingdom.

```bash
## Set to 'off' to disable the admin panel.
## 
## Default: off
## 
## Acceptable values:
##   - on or off
riak_control = on

## Authentication mode used for access to the admin panel.
## 
## Default: off
## 
## Acceptable values:
##   - one of: off, userlist
riak_control.auth.mode = on

## If riak control's authentication mode (riak_control.auth.mode)
## is set to 'userlist' then this is the list of usernames and
## passwords for access to the admin panel.
## To create users with given names, add entries of the format:
## riak_control.auth.user.USERNAME.password = PASSWORD
## replacing USERNAME with the desired username and PASSWORD with the
## desired password for that user.
## 
## Acceptable values:
##   - text
riak_control.auth.user.admin.password = lovesecretsexgod
```

![Snapshot View](../assets/control-snapshot.png)

With Control in place, restart your node and connect via a browser (note you're using
`https`) `https://localhost:8069/admin`. After you log in using the user you set, you
should see a snapshot page, which communicates the health of your cluster.

If something is wrong, you'll see a huge red "X" instead of the green check mark, along
with a list of what the trouble is.

From here you can drill down into a view of the cluster's nodes, with details on memory usage, partition distribution, and other status. You can also add and configure these nodes, then view the plan and status of those changes.

![Cluster View](../assets/control-cluster.png)

There is more in line for Riak Control, like performing MapReduce queries, stats views,
graphs, and more coming down the pipe. It's not a universal toolkit quite yet,
but it has a phenomenal start.

Once your cluster is to your liking, you can manage individual nodes, either stopping or taking them down permanently. You can also find a more detailed view of an individual node, such as what percentage of the cluster it manages, or its RAM usage.

![Node Management View](../assets/control-node-mgmt.png)

<!-- ## Scaling Riak
Vertically (by adding bigger hardware), and Horizontally (by adding more nodes).
 -->

## Wrap-up

Once you comprehend the basics of Riak, it's a simple thing to manage. If this seems like
a lot to swallow, take it from a long-time relational database guy (me), Riak is a
comparatively simple construct, especially when you factor in the complexity of
distributed systems in general. Riak manages much of the daily tasks an operator might
do themselves manually, such as sharding by keys, adding/removing nodes, rebalancing data,
supporting multiple backends, and allowing growth with unbalanced nodes.
And due to Riak's architecture, the best part of all is when a server goes down at night,
you can sleep (do you remember what that was?), and fix it in the morning.
