# Writing Riak Applications

# Riak写作的应用
Chapters 2 and 3 covered key concepts that every developer should
know. In this chapter, we look more closely at ways to build (and more
importantly not to build) Riak applications.
第2章和第3章涵盖了每个开发人员应该掌握的关键概念。在本章中，我们更仔细地看如何创建（和更重要的是不创建）Riak 应用。
## How Not to Write a Riak App
# #如何写Riak App
Writing a Riak application is very much **not** like writing an
application that relies on a relational database. The core ideas and
vocabulary from database theory still apply, of course, but many of
the decisions that inform the application layer are transformed.
写一个Riak应用很*不*像写一个依赖于关系数据库的应用程序。当然，数据库理论的核心思想和词汇仍然适用，但是许多通知应用层的决定都被改变了。
Effectively, _all_ of these anti-patterns make some degree of sense when
writing an application against an RDBMS (such as MySQL). Unfortunately,
_none_ of them lend themselves to great Riak applications.
实际上，所有这些反模式做出某种程度上编写应用程序时对关系数据库（如MySQL）。不幸的是，它们中没有一个自己伟大的Riak的应用。
### Dynamic querying
# # #动态查询
Riak's tools for finding data (2i, MapReduce, and full-text search)
are useful but should be used judiciously. None of these scale nearly
as well as key/value operations. Queries that may work well on a few
nodes in development may run more slowly in a busy production
environment, especially as the cluster grows in size.
寻找数据的Riak工具（2i，MapReduce，全文搜索）是有用的但应谨慎使用。它们中没有一个规模几乎差不多以及关键/值操作。在开发中的几个节点上运行良好的查询可能会在忙碌的生产环境中运行得更慢，特别是当集群的大小增长时
Key/value operations seem primitive (and they are) but you'll find that
they are flexible, scalable, and very, very fast (and predictably so).
One thing to always bear in mind about key/value operations:
关键/值操作看起来是原始的（并且它们确实是），但是你会发现它们是灵活的，可扩展的，而且非常快（可以预见的）.关于关键/值操作有一件事要一直记在心里：
*Reads and writes in Riak should be as fast with ten billion values
in storage as with ten thousand.*
*Riak里的读写应尽量快速一百亿值存储为一万*。
Design the main functionality of your application around the straight
key/value operations that Riak provides and your software will
continue to work at blazing speeds when you have petabytes of data
stored across dozens of servers.
设计您的应用程序在直键/值的主要业务功能，Riak提供和你的软件将继续以惊人的速度当你有几十个服务器存储PB级数据的工作。
### Normalization
###规范化
Normalizing data is generally a useful approach in a relational
database, but it is unlikely to lead to happy results with Riak.
规范数据通常是在关系型数据库中的一个有用的方法，但它不太可能导致与Riak高兴的结果。
Riak lacks foreign key constraints and join operations, two vital
parts of the normalization story, so reconstructing a single record
from multiple objects would involve multiple read requests. This is
certainly possible and fast enough on a small scale, but it is not ideal
for larger requests.
Riak没有外键约束和连接操作，规范化故事的两个重要的部分，所以从多个对象中重建单个记录会涉及多个读请求。这确实是可能的，足够快的小规模，但它对于更大的要求并不理想。
In contrast, imagine the performance of your application if most of your
requests involved a single read operation. Much faster and predictably
so, even at scale. Preparing and storing the answers to
queries you're going to ask for later is a best practice for Riak.
与此相反，如果你的大多数请求涉及单个读操作，请想象应用程序的性能。更快速和可预见的是，即使在规模也一样。制备和存储你将要问Riak的答案是一项很好的练习。
See [Denormalization](#denormalization) for more discussion.
看[Denormalization](#denormalization) 进行更多的讨论
### Ducking conflict resolution
# # #回避冲突
One of the first hurdles Basho faced when releasing Riak was educating
developers on the complexities of eventual consistency and the need to
intelligently resolve data conflicts.
第一个Basho所面临的问题是当释放Riak时教育开发商的最终一致性，以及需要智能化的解决数据冲突的复杂性。
Because Riak is optimized for high availability, *even when servers
are offline or disconnected from the cluster due to network failures*,
it is not uncommon for two servers to have different versions of a
piece of data.
因为Riak是高可用性优化，即使当服务器脱机或因网络故障的集群服务器断开连接，对于两个服务器关于同一部分数据有不同版本，这是不寻常的。
The simplest approach to coping with this is to allow Riak to choose a
winner based on timestamps. It can do this more effectively if
developers follow Basho's guidance on sending updates with *vector
clock* metadata to help track causal history. But concurrent updates
cannot always be automatically resolved via vector clocks, and
trusting server clocks to determine which write was the last to arrive
is a **terrible** conflict resolution method.
为了应对这种问题，最简单的方法是让Riak选择一个基于时间戳的赢家。如果开发商按照Basho的指导，发送更新*向量时钟*元数据帮助追踪因果历史会很有效。但并发更新不能总是通过矢量时钟自动解决，并且信任服务器时钟以确定哪一个写入是最后到达的是一个***可怕的*冲突解决方法。
Even if your server clocks are magically always in sync, are your
business needs well served by blindly applying the most recent update?
Some databases have no alternative but to handle it that way, but we think
you deserve better.
即使你的服务器时钟总是神奇的同步，你的业务需要很好地服务通过盲目地应用最新的更新？有些数据库没有办法，只能这样处理，但我们认为你应该得到更好的。
Typed buckets in Riak 2.0 default to retaining conflicts and requiring
the application to resolve them, but we're also providing replicated,
conflict-free data types (we call them Riak Data Types) to automate
conflict resolution on the server side.
Riak 2的典型是大量默认保留的冲突，需要应用程序来解决，但我们也提供复制，无冲突的数据类型（我们称之为Riak数据类型）来自动解决冲突在服务器端。
If you want to minimize the need for conflict resolution, modeling
with as much immutable data as possible is a big win.
如果你想最小化解决冲突，尽可能多的不可变数据建模是一个巨大的胜利。
[Conflict Resolution](#conflict-resolution) covers this in much more detail.
[Conflict Resolution](#conflict-resolution)揭示更多细节。
### Mutability
# # #易变性
For years, functional programmers have been singing the praises of
immutable data, which can confer significant advantages when using a
distributed datastore like Riak.
多年来，多功能的程序员一直赞美能够带来显著的优势采用分布式数据存储的时候像Riak之类的不可变数据。
Most obviously, conflict resolution is dramatically simplified when
objects are never updated (because it is avoided entirely).
最明显的是，当对象不被更新（因为它完全被避免）时，冲突消解被大大简化了。
Even in the world of single-server database servers, updating records
in place carries costs. Most databases lose all sense of history when
data is updated, and it's entirely possible for two different clients
to overwrite the same field in rapid succession, leading to unexpected
results.
即使在单一服务器数据库服务器的世界，更新记录也需要成本。大多数数据库在数据更新时失去了所有的历史，并且这两个不同的客户完全有可能连续快速地覆盖同一个字段，导致意想不到的结果。
Some data is always going to be mutable, but thinking about the
alternative can lead to better design.
有些数据总是可变的，但考虑替代方案可能会导致更好的设计。
### SELECT * FROM &lt;table&gt;

A perfectly natural response when first encountering a populated
database is to see what's in it. In a relational database, you can
easily retrieve a list of tables and start browsing their records.
第一次遇到一个数据众多的数据库时，一个非常自然的反应就是看看里面有什么。在关系数据库中，您可以轻松地检索表的列表，并开始浏览它们的记录。
As it turns out, this is a terrible idea in Riak.
当它发生的时候，在Riak中是一个糟糕的主意。
Not only is Riak optimized for unstructured, opaque data, it is also
not designed to allow for trivial retrieval of lists of buckets (very
loosely analogous to tables) and keys.
Riak不仅是结构化的，不透明的数据优化，它也不是被设计来允许列表的桶的琐碎的检索（非常松散的类似于表）和钥匙。
Doing so can put a great deal of stress on a large cluster and can
significantly impact performance.
这样做可以把大量的压力放在一个大的集群，可以显著地影响性能。
It's a rather unusual idea for someone coming from a relational
mindset, but being able to algorithmically determine the key that you
need for the data you want to retrieve is a major part of the Riak
application story.
这是一个相当不寻常的想法来自一个有关的思维倾向，但能够通过算法确定的关键，你需要为你想获得的数据是Riak应用文件的主要部分。
### Large objects
# # #大对象
Because Riak sends multiple copies of your data around the network for
every request, values that are too large can clog the pipes, so to
speak, causing significant latency problems.
因为Riak传送多个会将你的数据要求在网络中的每个请求的副本，太大了会堵塞管道，所以说，造成了严重的延迟问题。
Basho generally recommends 1-4MB objects as a soft cap; larger sizes
are possible with careful tuning, however.
Basho 一般建议1 - 4MB的对象作为一个软顶；但是，大尺寸仔细调整是可能的。
We'll return to object size when discussing [Conflict Resolution](#conflict-resolution); for
the moment, suffice it to say that if you're planning on storing
*mutable* objects in the upper ranges of our recommendations, you're
particularly at risk of latency problems.
讨论[Conflict Resolution](#conflict-resolution);时我们会返回对象的大小，现在，如果你打算在我们建议的上限范围内存储*可变的*对象，就足够了，尤其是在延迟问题的风险中。
For significantly larger objects,
[Riak CS](http://basho.com/riak-cloud-storage/) offers an Amazon
S3-compatible (and also OpenStack Swift-compatible) key/value object
store that uses Riak under the hood.
对于较大的物体，[Riak CS ]（http://basho.com/riak-cloud-storage/）提供了一个亚马逊S3兼容的（也是OpenStack Swift兼容）键/值的对象存储使用Riak的引擎盖下。
### Running a single server
# # #运行单一服务器
This is more of an operations anti-pattern, but it is a common
misunderstanding of Riak's architecture.
这是一个操作的反模式，但它是Riak建筑中的一个常见的误解。
It is quite common to install Riak in a development environment using
its `devrel` build target, which creates 5 full Riak stacks (including
Erlang virtual machines) to run on one server to simulate a cluster.
这是很常见的安装Riak利用其` devrel `构建目标在开发环境中，创造了5 Riak stacks（包括Erlang虚拟机）上运行一个服务器来模拟集群。
However, running Riak on a single server for benchmarking or
production use is counterproductive, regardless of whether you have 1
stack or 5 on the box.
然而，对标杆管理或生产使用，一台服务器上运行的Riak，不管你是否有1堆或5盒。
It is possible to argue that Riak is more of a database coordination
platform than a database itself. It uses Bitcask or LevelDB to persist
data to disk, but more importantly, it commonly uses *at least* 64
such embedded databases in a cluster.
可以说，Riak是一个数据库协调平台不仅仅是数据库本身。它采用bitcask或LevelDB保存数据到磁盘，但更重要的是，它通常使用*至少* 64嵌入式数据库集群。
Needless to say, if you run 64 databases simultaneously on a single
filesystem you are risking significant I/O and CPU contention unless
the environment is carefully tuned (and has some pretty fast disks).
不用说，如果你在一个文件系统上同时运行64个数据库，你会冒很大的I/O和CPU矛盾，除非环境被仔细调整过（并且有一些非常快的磁盘）。
Perhaps more importantly, Riak's core design goal, its raison d'être,
is high availability via data redundancy and related
mechanisms. Writing three copies of all your data to a single
server is mostly pointless, both contributing to resource contention
and throwing away Riak's ability to survive server failure.
也许更重要的是，Riak核心设计目标，其存在的êTRE，通过数据冗余、高可用性的相关机制。写三份你所有的数据到一个单一的服务器是没有意义的，资源的争夺和抛弃Riak的生存能力服务器故障都有益处。
### Further reading
# # #进一步阅读
* [Why Riak](http://docs.basho.com/riak/latest/theory/why-riak/) (docs.basho.com)
* [Data Modeling](http://docs.basho.com/riak/latest/dev/data-modeling/) (docs.basho.com)
* [Clocks Are Bad, Or, Welcome to the Wonderful World of Distributed Systems](https://basho.com/clocks-are-bad-or-welcome-to-distributed-systems/) (Basho blog)


## Denormalization
## 非规范化
Normal forms are the holy grail of schema design in the relational
world. Duplication is misery, we learn. Disk space is constrained, so
let foreign keys and join operations and views reassemble your data.
范式是关系世界中图式设计的圣杯。重复是痛苦的，我们学习。磁盘空间是受限制的，让外部的按键和连接操作和视图重新组装你的数据。
Conversely, when you step into a world *without* join operations,
**stop normalizing**. In fact, go the other direction, and duplicate
your data as much as you need to. Denormalize all the things!
相反，当你踏入一个*没有*连接的世界时，*停止正常化*。事实上，去另一个方向，重复你的数据，只要你需要。非规范化化所有的东西！
I'm sure you immediately thought of a few objections to
denormalization; I'll do what I can to dispel your fears. Read on,
Macduff.
我肯定你马上有一些反对非规范化的想法；我会尽我所能消除你的恐惧。读一读，Macduff.
### Disk space
# # #磁盘空间
Let me get the easy concern out of the way: don't worry about disk
space. I'm not advocating complete disregard for it, but one of the
joys of operating a Riak database is that adding more computing
resources and disk space is not a complex, painful operation that
risks downtime for your application or, worst of all, manual sharding
of your data.
我来表达不正常的简单观点：不要担心磁盘空间。我并不提倡完全漠视，但其中操作Riak数据库的乐趣在于增加更多的计算资源并且磁盘空间不是一个复杂的、痛苦的操作风险的停机时间为您的应用程序，最糟糕的是，手动分片你的数据。
Need more disk space? Add another server. Install your OS, install
Riak, tell the cluster you want to join it, and then pull the
trigger. Doesn't get much easier than that.
需要更多磁盘空间吗？添加另一台服务器。安装您的操作系统，安装Riak，告诉群你想加入它，然后扣动扳机。不会更容易了。
### Performance over time
### 随着时间的执行
If you've ever created a *really* large table in a relational
database, you have probably discovered that your performance is
abysmal. Yes, indexes help with searching large tables, but
maintaining those indexes are **expensive** at large data sizes.
如果你曾经创造了一个*真的*大表在关系数据库中，你可能发现你的执行糟透了。是的，索引有助于查找大型表，但维护这些索引在大数据量上是**昂贵**的。
Riak includes a data organization structure vaguely similar to a
table, called a *bucket*, but buckets don't carry the indexing
overhead of a relational table. As you dump more and more data into a
bucket, write (and read) performance is constant.
Riak包括一个数据组织结构大致相似的一个表，称为*bucket*，但桶不携带一个关系表的索引的花费。当你将越来越多的数据转储到一个桶中时，写（读）的性能是不变的。
### Performance per request
# # #性能要求
Yes, writing the same piece of data multiple times is slower than
writing it once, by definition.
是的，根据定义，多次写入同一条数据比写一次慢。
However, for many Riak use cases, writes can be asynchronous. No one
is (or should be) sitting at a web browser waiting for a sequence of
write requests to succeed.
然而，对于许多Riak例子，写可以异步。没有一个（或者应该）坐在网络浏览器上等待一系列写请求成功。
What users care about is **read** performance. How quickly can you
extract the data that you want?
用户关心的是**写的**性能。如何快速地提取您想要的数据？
Unless your application is receiving many hundreds or thousands of new
pieces of data per second to be stored, you should have plenty of time
to write those entries individually, even if you write them multiple
times to different keys to make future queries faster. If you really
*are* receiving so many objects for storage that you don't have time
to write them individually, you can buffer and write blocks of them in
chunks.
除非你的应用程序每秒接收几百或几千个新的数据块，否则你应该有足够的时间单独编写这些条目，即使你将它们多次写入不同的键，以使将来的查询更快。如果你真的要接收这么多的对象存储，却没有时间单独写，你可以缓冲和分块。
In fact, a common data pattern is to assemble multiple objects into
larger collections for later retrieval, regardless of the ingest rate.
事实上，一个共同的数据模式是将多个对象组装成较大的集合，以便以后的检索，而不管其摄取率如何
### What about updates?
### 如何更新？
One key advantage to normalization is that you only have to update any
given piece of data once.
标准化的一个主要优点是，你只需要更新给定的数据一次。
However, many use cases that require large quantities of storage deal
with mostly immutable data, such as log entries, sensor readings, and
media storage. You don't change your sensor data after it arrives, so
why do you care if each set of inputs appears in five different places
in your database?
然而，有许多使用的情况是，需要大量的存储处理的大多是不可变的数据，如日志条目，传感器读数，和媒体存储。你的传感器数据到达后不进行改变，那么为什么你关心数据库中如果每一组输入出现在五个不同的地方？
Any information which must be updated frequently should be confined to
small objects that are limited in scope.
任何必须经常更新的信息都应限于范围有限的小对象。
We'll talk much more about data modeling to account for mutable and
immutable data.
我们将讨论更多的数据模型来解释易变的和不可变的数据。
### Further reading
# # #进一步阅读
* [NoSQL Data Modeling Techniques](http://highlyscalable.wordpress.com/2012/03/01/nosql-data-modeling-techniques/) (Highly Scalable Blog)


## Data modeling
# #数据建模
It can be hard to think outside the table, but once you do, you may
find interesting patterns to use in any database, even a
relational one.[^sql-databases]
想表的外部可能是难的，但一旦你这样做，你可能会发现在任何数据库中有趣的模式，即使是关系数据库。[^sql-databases]
[^sql-databases]: Feel free to use a relational database when you're
willing to sacrifice the scalability, performance, and availability of
Riak...but why would you?
[^sql-databases]:随意使用关系数据库的时候，你愿意牺牲的可扩展性、性能和可用性的Riak…但为什么这样？
If you thoroughly absorbed the earlier content, some of this may feel
redundant, but the implications of the key/value model are not always
obvious.
如果你完全理解了前期的内容，其中一些可能会觉得多余，但重点/价值模式的影响并不总是明显的。
### Rules to live by
### 生活的规则
As with most such lists, these are guidelines rather than hard rules,
but take them seriously.
与大多数这样的清单一样，这些都是指导方针而不是硬性规定，但要严肃对待。
(@keys) Know your keys.

    The cardinal rule of any key/value datastore: the fastest way to get
    data is to know what to look for, which means knowing which key you want.
    任何键/值数据存储的基本规则：获取数据的最快方法是知道要寻找什么，这意味着你知道你想要的键。
    How do you pull that off? Well, that's the trick, isn't it?
    你怎么把它关掉？嗯，这就是窍门，不是吗？
    The best way to always know the key you want is to be able to
    programmatically reproduce it based on information you already
    have. Need to know the sales data for one of your client's
    magazines in December 2013? Store it in a **sales** bucket and
    name the key after the client, magazine, and month/year combo.
    最好的方法总是知道你想要的关键是能够以编程方式复制它的基础上你已经有信息。需要知道你的客户杂志的销售数据在2013十二月？将它存储在一个销售桶中，并在客户、杂志和月/年组合后将其命名。
    Guess what? Retrieving it will be much faster than running a SQL
    `SELECT *` statement in a relational database.
    你猜怎么着？检索它将比在关系数据库中运行sql SELECT语句要快得多。
    And if it turns out that the magazine didn't exist yet, and there
    are no sales figures for that month? No problem. A negative
    response, especially for immutable data, is among the fastest
    operations Riak offers.
    如果事实证明这本杂志还不存在，那一个月就没有销售数据了？没问题。负面的反应，尤其对于不可变的数据，Riak提供了最快的操作。
    Because keys are only unique within a bucket, the same unique
    identifier can be used in different buckets to represent different
    information about the same entity (e.g., a customer address might
    be in an `address` bucket with the customer id as its key, whereas
    the customer id as a key in a `contacts` bucket would presumably
    contain contact information).
    因为钥匙在桶是独特的，相同的唯一标识符可以用在不同的桶来表示同一实体的不同的信息（例如，一个客户的地址可能是一个`地址`桶客户ID是关键，而客户ID作为一个关键的一`接触`桶大概会包含联系信息）。
(@namespace) Know your namespaces.
(@namespace)知道你的命名空间
    Riak has several levels of namespaces when storing data.
    Riak有几个层次存储数据时的命名空间。
    Historically, buckets have been what most thought of as Riak's
    virtual namespaces.
    从历史上看，桶已经被大部分认为Riak的虚拟命名空间。
    The newest level is provided by **bucket types**, introduced in Riak 2.0, which
    allow you to group buckets for configuration and security purposes.
    最新的水平是由**桶型**，在Riak 2.0中有介绍，这允许你组桶的配置和安全目的。
    Less obviously, keys are their own namespaces. If you want a
    hierarchy for your keys that looks like `sales/customer/month`,
    you don't need nested buckets: you just need to name your keys
    appropriately, as discussed in (@keys). `sales` can be your
    bucket, while each key is prepended with customer name and month.
    不太明显的是，密钥是它们自己的命名空间。如果你想要一个看起来像“销售/客户/月份”的密钥的层次结构，你不需要嵌套的桶：你只需要适当地命名你的密钥，如在（@键）中所讨论的那样。`销售`可以成为你的桶，而每个键前加上客户的名字和月。
(@views) Know your queries.
(@views)知道你的查询
    Writing data is cheap. Disk space is cheap. Dynamic queries in Riak
    are very, very expensive.
    写数据很便宜。磁盘空间便宜。在Riak的动态查询是非常，非常昂贵。
    As your data flows into the system, generate the views you're going to
    want later. That magazine sales example from (@keys)? The December
    sales numbers are almost certainly aggregates of smaller values, but
    if you know in advance that monthly sales numbers are going to be
    requested frequently, when the last data arrives for that month the
    application can assemble the full month's statistics for later
    retrieval.
    当您的数据流入系统，生成您以后想要的视图。那个杂志的销售例子来自于（@键）？十二月的销售数字几乎肯定是较小值的聚集，但是如果你事先知道每月的销售数量会被频繁地请求，当最后一个数据到达当月时，应用程序可以组装完整的月份的统计数据以便以后的检索。
    Yes, getting accurate business requirements is non-trivial, but
    many Riak applications are version 2 or 3 of a system, written
    once the business discovered that the scalability of MySQL,
    Postgres, or MongoDB simply wasn't up to the job of handling their
    growth.
    是的，得到准确的业务需求是微不足道的，但许多Riak应用程序版本2或3的一个系统，编写一次业务发现，MySQL，Postgres，或MongoDB的增长，不仅仅处理增长的工作。
(@small) Take small bites.
(@small) 获得小的机内测试设备
    Remember your parents' advice over dinner? They were right.
    记得你父母在晚餐时的建议吗？他们是对的。
    When creating objects that will be updated, constrain their scope
    and keep the number of contained elements low to reduce the odds
    of multiple clients attempting to update the data concurrently.
    当创建将被更新的对象时，限制其范围并保持所包含的元素的数量低，以减少多个客户端试图同时更新数据的可能性。
(@indexes) Create your own indexes.
(@indexes) 创建自己的索引
    Riak offers metadata-driven secondary indexes (2i) and full-text indexes
    (Riak Search) for values, but these face scaling challenges: in
    order to identify all objects for a given index value, roughly a
    third of the cluster must be involved.
    Riak提供了元数据驱动的二级指标（2i）和全文索引（Riak搜索）的价值观，但这些面对范围的挑战：为了确定所有对象对于一个给定的索引值，大约三分之一的集群必须参与。
    For many use cases, creating your own indexes is straightforward
    and much faster/more scalable, since you'll be managing and
    retrieving a single object.
    对于许多例子来说，创建您自己的索引是简单的，并且更快/更易于扩展，因为您将管理和检索单个对象。
    See [Conflict Resolution](#conflict-resolution) for more discussion of this.
    看 [Conflict Resolution](#conflict-resolution)是为了讨论。
(@immutable) Embrace immutability.
(@immutable)拥抱永恒
    As we discussed in [Mutability], immutable data offers a way out
    of some of the challenges of running a high-volume, high-velocity
    datastore.
    当我们讨论[无常]时，不可变的数据提供了一种方法，一些挑战运行大容量、高速度的数据存储。
    If possible, segregate mutable from non-mutable data, ideally
    using different buckets for [request tuning][Request tuning].
   如果可能的话，从非可变数据中隔离可变数据，理想情况下在 [request tuning]中使用不同的桶。
    [Datomic](http://www.datomic.com) is a unique data storage system
    that leverages immutability for all data, with Riak commonly used
    as a backend datastore. It treats any data item in its system as
    a "fact," to be potentially superseded by later facts but never
    updated.
  [Datomic](http://www.datomic.com)是一个独特的数据存储系统，利用不变性的所有数据，常用Riak作为后台数据存储。它将系统中的任何数据项视为“事实”，可能被后来的事实所代替，但从未更新过。
(@hybrid) Don't fear hybrid solutions.
(@hybrid)不要害怕混合解决方案。
    As much as we would all love to have a database that is an excellent
    solution for any problem space, we're a long way from that goal.
    我们都喜欢有一个很好的解决任何问题的空间的数据库，我们有很长的路要走这个目标。
    In the meantime, it's a perfectly reasonable (and very common)
    approach to mix and match databases for different needs. Riak is
    very fast and scalable for retrieving keys, but it's decidedly
    suboptimal at ad hoc queries. If you can't model your way out of
    that problem, don't be afraid to store keys alongside searchable
    metadata in a relational or other database that makes querying
    simpler, and once you have the keys you need, grab the values
    from Riak.
    同时，为不同的需求混合和匹配数据库是一种完全合理的（非常常见的）方法。Riak可以很快的和可扩展的检索关键字，但它是非常不理想的即席查询。如果你的方法模型不能解决这个问题，不要害怕存储密钥在关系数据库或其他数据库，使查询更简单的可搜索的元数据，而一旦你有你需要的钥匙，从Riak中获取数值。
    Just make sure that you consider failure scenarios when doing so;
    it would be unfortunate to compromise Riak's availability by
    rendering it useless when your other database is offline.
    只是确保你这样做要考虑失败的情况；妥协Riak的可用性使它无用时是不幸的，你的其他数据库脱机。
### Further reading

* [Use Cases](http://docs.basho.com/riak/latest/dev/data-modeling/)



## Conflict Resolution
# #解决冲突
Conflict resolution is an inherent part of nearly any Riak
application, whether or not the developer knows it.
冲突的解决是几乎任何风险的应用程序中固有的一部分，不论它的开发者是否知道。
### Conflict resolution strategies
# # #冲突解决策略
There are basically 6 distinct approaches for dealing with conflicts
in Riak, and well-written applications will typically use a
combination of these strategies depending on the nature of the data.[^conflict-tuning]
基本上Riak中冲突的处理有6种不同的方法，编写的应用程序通常会同时使用取决于数据的性质，这些策略。
[^conflict-tuning]: If each bucket has its own conflict resolution
strategy, requests against that bucket can be tuned appropriately. For
an example, see [Tuning for immutable data].
[^conflict-tuning]: 如果每个桶都有自己的冲突解决策略，则可以适当调整对该桶的请求。例如，参见[不可变数据的调整]。
* Ignore the problem and let Riak pick a winner based on timestamp and
  context if concurrent writes are received (aka "last write wins").
* Immutability: never update values, and thus never risk conflicts.
* Instruct Riak to retain conflicting writes and resolve them with
  custom business logic in the application.
* Instruct Riak to retain conflicting writes and resolve them using
  client-side data types designed to resolve conflicts automatically.
* Instruct Riak to retain conflicting writes and resolve them using
  server-side data types designed to resolve conflicts automatically.
  *忽略这个问题，让Riak选择一个成功的基于时间戳和
  如果并发写入接收上下文（也称为“上次写入WINS”）。
  *不变性：从不更新值，因而没有风险的冲突。
  *指导风险保留冲突写入和解决
  应用程序中的自定义业务逻辑。
  *指导风险保留冲突写入和解决使用
  自动解决冲突的客户端数据类型。
  *指导风险保留冲突写入和解决使用
  服务器端数据类型设计，自动解决冲突。
And, as of Riak 2.0, strong consistency can be used to avoid conflicts
(but as we'll discuss below there are significant downsides to doing
so).
而且，作为Riak 2.0，强一致性可以用来避免冲突（我们将在下面讨论有这样显著的缺点）。

### Last write wins
# # #最后写胜
Prior to Riak 2.0, the default behavior was for Riak to resolve
siblings by default (see [Tuning parameters](#tuning-parameters) for the parameter
`allow_mult`). With Riak 2.0, the default behavior changes to
retaining siblings for the application to resolve, although this will
not impact legacy Riak applications running on upgraded clusters.
Riak 2之前，默认行为是风险化解的兄弟姐妹（见[默认]（#调谐参数整定参数）的参数` allow_mult `）。与风险2、违约行为的变化来保持解决应用的兄弟姐妹，虽然这不会影响应用程序运行的集群升级遗留风险。
For some use cases, letting Riak pick a winner is perfectly fine, but
make sure you're monitoring your system clocks and are comfortable
losing occasional (or not so occasional) updates.
在某些情况下，让Riak挑选一个冠军是很好的，但要确保你监控你的系统时钟和舒适失去偶尔（或者不那么偶然）的更新。
### Data types
# # #数据类型
It has always been possible to define data types on the client side to
merge conflicts automatically.
在客户端定义数据类型以自动合并冲突一直是可能的。
With Riak 1.4, Basho started introducing distributed data types
(formally known as **CRDTs**, or conflict-free replicated data types)
to allow the cluster to resolve conflicting writes automatically. The
first such type was a simple counter; Riak 2.0 adds sets and maps.
Riak1.4，Basho开始引入分布式数据类型（正式名称为**CRDTs **，或无冲突的复制的数据类型）允许集群写自动解决冲突。第一类是一个简单的计数器；风险2增加了集合与映射。
These types are still bound by the same basic constraints as the rest
of Riak. For example, if the same set is updated on either side of a
network split, requests for the set will respond differently until the
split heals; also, these objects should not be allowed to grow to
multiple megabytes in size.
这些类型仍然遵守一个基本约束作为Riak的剩余部分。例如，如果同一集在网络拆分的任何一方更新，则该集合的请求将响应不同，直到拆分愈合；并且，这些对象不应该允许在大小上增长到多兆字节。
### Strong consistency
# # #强一致性
As of Riak 2.0, it is possible to indicate that values should be
managed using a consensus protocol, so a quorum of the servers
responsible for that data must agree to a change before it is
committed.
作为Riak2.0，使用一致性协议管理的数值是可能的，所以一个群体负责，数据必须同意改变它之前承诺的服务器。
This is a useful tool, but keep in mind the tradeoffs: writes will be
slower due to the coordination overhead, and Riak's ability to
continue to serve requests in the presence of network partitions and
server failures will be compromised.
这是一个有用的工具，但记住：由于协调开销，写会慢一些，和Riak继续服务于网络分区的能力和服务器出现故障时要求将受到损害。
For example, if a majority of the primary servers for the data are
unavailable, Riak will refuse to answer read requests if the surviving
servers are not certain the data they contain is accurate.
例如，如果数据大部分初级服务器都不可用，Riak会拒绝回答读请求如果幸存的服务器不一定包含的数据是准确的。
Thus, use this only when necessary, such as when the consequences of
conflicting writes are painful to cope with. An example of the need
for this comes from Riak CS: because users are allowed to create new
accounts, and because there's no convenient way to resolve username
conflicts if two accounts are created at the same time with the same
name, it is important to coordinate such requests.
因此，只有在必要时使用这一点，如冲突的书面后果是痛苦的，以应付。为此需要一个例子来自Riak的CS：因为允许用户创建新帐户，因为如果两个账户在具有相同名称的同时创造了没有方便的方法来解决用户名冲突，是协调这些要求的重要。
### Conflicting resolution
# # #冲突的解决
Resolving conflicts when data is being rapidly updated can feel
Sysiphean.
解决冲突的数据时，可以感受到Sysiphean的快速更新。
It's always possible that two different clients will attempt to
resolve the same conflict at the same time, or that another client
will update a value between the time that one client retrieves
siblings and it attempts to resolve them. In either case you may have
new conflicts created by conducting conflict resolution.
两个不同的客户端总是试图同时解决同一个冲突，或者另一个客户端在一个客户机检索兄弟姐妹的时候更新一个值，并试图解决这些问题。在这两种情况下，您可能会产生新的冲突进行冲突解决。
Consider this yet another plug to consider immutability.
认为这是另一个插头考虑不变性。
### Further reading

* [Clocks Are Bad, Or, Welcome to the Wonderful World of Distributed Systems](http://basho.com/clocks-are-bad-or-welcome-to-distributed-systems/) (Basho blog)
* [Index for Fun and for Profit](http://basho.com/index-for-fun-and-for-profit/) (Basho blog)
* [Readings in conflict-free replicated data types](http://christophermeiklejohn.com/crdt/2014/07/22/readings-in-crdts.html) (Chris Meiklejohn's blog)

## Request tuning
# #要求调整
Riak is extensively (perhaps *too* extensively) configurable. Much of
that flexibility involves platform tuning accessible only via the host
operating system, but several core behavioral values can (and should)
be managed by applications.
Riak是广泛的（也许是*太*广泛）配置。大部分的灵活性包括平台的调整，只有通过主机操作系统访问，但几个核心行为值可以（并且应该）由应用程序管理。
With the notable exceptions of `n_val` (commonly referred to as `N`)
and `allow_mult`, the parameters described below can be overridden
with each request. All of them can be configured per-bucket type
(available with Riak 2.0) or per-bucket.
与例外的` n_val `（通常被称为` N `）和` allow_mult `，下面描述的参数可以覆盖每个请求。他们都可以配置每桶类型（Riak 2可获取）或每桶。
### Key concepts
# # #关键概念
Any default value listed below as **quorum** is equivalent to
`n_val/2+1`, or **2** whenever `n_val` has not been modified.
下面列出的任何默认值为××××`人数相当于n_val / 2 + 1 `，或* 2 *每当` n_val `尚未修改。
**Primary** servers are the cluster members that, in the absence of any
network or server failure, are supposed to "own" any given key/value
pair.
**初级服务器是群集成员，在没有任何网络或服务器故障的情况下，应该“拥有”任何给定的键/值对。
Riak's key/value engine does not itself write values to storage. That
job is left to the **backends** that Riak supports: Bitcask, LevelDB,
and Memory.
Riak的键/值发动机本身不写值存储。这项工作是留给Riak的支持**的后台* *：Bitcask，LevelDB，Memory。
No matter what the parameters below are set to, requests will be
sent to `n_val` servers on behalf of the client, **except** for
strongly-consistent read requests with Riak 2.0, which can be safely
retrieved from the current leader for that key/value pair.
不管下面的参数设置，请求将被发送到` n_val `代表客户端服务器，**除**强一致性读与Riak 2.0方面的要求，它可以安全地检索从目前的领导人为键/值对。
### Tuning parameters
# # #调谐参数
#### Leave this alone
### 单独留下
`n_val`
:   The number of copies of data that are written. This is independent of the number of servers in the cluster. Default: **3**.
`n_val`：写入的数据的拷贝数。这与群集中的服务器数无关。默认值：** 3 **。
The `n_val` is vital to nearly everything that Riak does. The default
value of 3 should never be lowered except in special circumstances,
and changing it after a bucket has data can lead to unexpected
behavior.
` n_val `是几乎所有Riak创造中是至关重要的。除非在特殊情况下，3的默认值不应该被降低，而且在桶中有数据后改变它可能会导致意外的行为。
#### Configure at the bucket
### 桶里的配置
`allow_mult`
:    Specify whether this bucket retains conflicts for the application to resolve (`true`) or pick a winner using vector clocks and server timestamp even if the causality history does not indicate that it is safe to do so (`false`). See [Conflict Resolution](#conflict-resolution) for more. Default: **`false`** for untyped buckets (including all buckets prior to Riak 2.0), **`true`** otherwise
    You **should** give this value careful thought. You **must** know what it will be in your environment to do proper key/value data modeling.
`allow_mult`：指定此桶是否保留应用程序解决冲突（'真'）或选择一个赢家使用矢量时钟和服务器的时间戳，即使因果关系的历史并不表明它是安全的这样做（'假'）。看到[冲突]（#冲突解决）更多。默认值：* * * `假`无类型（包括所有的桶桶Riak 2之前），××`真` ** ** **否则应该给这个值仔细思考。你必须知道在你的环境中做适当的关键/值数据建模是什么。
`last_write_wins`
:    Setting this to `true` is a slightly stronger version of `allow_mult=false`: when possible, Riak will write new values to storage without bothering to compare against existing values. Default: **`false`**
`last_write_wins`：设置为`true`是略强版` allow_mult =false`：如果可能的话，Riak会写新的值来存储而不是对现有的价值观比较。默认：**false* *
#### Configure at the bucket or per-request
# # # #配置在桶或按要求
`r`
:   The number of servers that must *successfully* respond to a read request before the client will be sent a response. Default: **`quorum`**
`r`
: 在客户端发送响应前必须成功响应读请求的服务器数量。默认：**quorum* **
`w`
:   The number of servers that must *successfully* respond to a write request before the client will be sent a response. Default: **`quorum`**
`w`
:在客户端发送响应前必须成功响应写入请求的服务器数量。默认：**quorum* **
`pr`
:    The number of *primary* servers that must successfully respond to a read request before the client will be sent a response. Default: **0**
`pr`
: 在客户端发送响应之前，必须成功响应读取请求的* *服务器的数量。默认值：** 0 **
`pw`
:    The number of *primary* servers that must successfully respond to a write request before the client will be sent a response. Default: **0**
`pw`
: 在客户端发送响应之前，必须成功响应写入请求的* *服务器的数量。默认值：** 0 **
`dw`
:    The number of servers that must respond indicating that the value has been successfully handed off to the *backend* for durable storage before the client will be sent a response. Default: **2** (effective minimum **1**)
`dw`
:必须响应的服务器数量，指示在客户端发送响应之前，该值已成功地传递到*后端*用于持久存储。默认值：** * 2 *（有效最小** * 1 **）
`notfound_ok`
:    Specifies whether the absence of a value on a server should be treated as a successful assertion that the value doesn't exist (`true`) or as an error that should not count toward the `r` or `pr` counts (`false`). Default: **`true`**
`notfound_ok`
: 指定是否在服务器上的值的缺失应被视为一个成功的断言，该值不存在（'true'）或作为一个错误，不应该计数的' r '或' pr '计数（'假'）。默认：**true* *

#### Impact
# # # #影响
Generally speaking, the higher the integer values listed above, the
more latency will be involved, as the server that received the request
will wait for more servers to respond before replying to the client.
一般来说，上面列出的整型值越高，会涉及到更多的延迟，因为接收到请求的服务器会等待更多的服务器在答复客户端之前响应。
Higher values can also increase the odds of a timeout failure or, in
the case of the primary requests, the odds that insufficient primary
servers will be available to respond.
较高的值也可以增加超时故障的概率，或在主请求的情况下，不足的主服务器将可用于响应。
### Write failures
# # #写失败
***Please read this. Very important. Really.***
***请阅读此。非常重要。真的。**
The semantics for write failure are *very different* under eventually
consistent Riak than they are with the optional strongly consistent
writes available in Riak 2.0, so I'll tackle each separately.
语义的写入失败是非常不同的最终一致性风险下比他们与可选的强一致写在Riak 2可用，所以我会处理分别。
#### Eventual consistency
# # # #最终一致性
In most cases when the client receives an error message on a write
request, *the write was not a complete failure*. Riak is designed to
preserve your writes whenever possible, even if the parameters for a
request are not met. **Riak will not roll back writes.**
在大多数情况下，当客户端在写请求接收错误消息时，*写不是一个完整的失败*。Riak是为了保护你的写作只要有可能，即使一个请求的参数不满足。* Riak不会回滚写道。* *
Even if you attempt to read the value you just tried to write and
don't find it, that is **not** definitive proof that the write was a
complete failure. (Sorry.)
即使你试图读值，你只是试图写，并没有找到它，这不是最终证明，写是一个完整的失败。（抱歉）
If the write is present on at least one server, *and* that server
doesn't crash and burn, *and* future updates don't supersede it,
the key and value written should make their way to all servers
responsible for them.
如果写在至少一个服务器上，*和*服务器没有崩溃和烧毁，*和*未来的更新不取代它，键和值被写应该以们的方式对所有服务器负责。
Retrying any updates that resulted in an error, with the appropriate
vector clock to help Riak intelligently resolve conflicts, won't cause
problems.
重试更新导致错误，用适当的向量时钟来帮助Riak聪明地化解矛盾，不会造成问题。
#### Strong consistency
# # # #强一致性
Strong consistency is the polar opposite from the default Riak
behaviors. If a client receives an error when attempting to write a
value, it is a safe bet that the value is not stashed somewhere in the
cluster waiting to be propagated, **unless** the error is a timeout,
the least useful of all possible responses.
强一致性是从违背Riak行为的对立面。如果客户端接收到一个错误尝试写一个值时，它是一个安全的赌注，价值不是藏在集群等待繁殖的地方，除非错误是超时的，所有可能的反应最有用。
No matter what response you receive, if you read the key and get the
new value back[^client-libs], you can be confident that all future
successful reads (until the next write) will return that same value.
无论你收到什么样的响应，如果你读到了键，并获得了新的值[^client-libs]，你可以确信所有将来成功的读取（直到下一次写入）将返回相同的值。
[^client-libs]: To be *absolutely certain* your value is in Riak after
a write error and a successful read, you can issue a new read request
not tied to any existing object; your client library could be caching
the value you just wrote.
[^client-libs]:要肯定你的值是在Riak写入错误和成功读取后，你可以发布一个新的读请求不依赖于任何现有的对象；你的客户端库可以缓存你刚才写的值。
### Tuning for immutable data
# # #调谐可变数据
If you constrain a bucket to contain nothing but immutable data, you
can tune for very fast responses to read requests by setting `r=1` and
`notfound_ok=false`.
如果你限制了一桶只有不可变的数据，你可以调整设置为` r = 1 `和` notfound_ok =false`读请求的快速响应。
This means that read requests will (as always) be sent to all `n_val`
servers, but the first server that responds with **a value other than
`notfound`** will be considered "good enough" for a response to the
client.
这意味着，读请求将（总是）被发送到所有` n_val `服务器，但第一个服务器响应值比其他` NOTFOUND ` 将被认为是“足够好”的响应到客户端。
Ordinarily with `r=1` and the default value `notfound_ok=true` if the
first server that responds doesn't have a copy of your data you'll get
a `not found` response; if a failover server happens to be actively
serving requests, there's a very good chance it'll be the first to
respond since it won't yet have a copy of that key.
一般` R = 1 `和默认值` notfound_ok =真正的`如果第一服务器响应没有复制你的数据，你会得到一个`没有发现`响应；如果故障转移服务器会积极的服务请求中，有一个很好的机会，它会是第一个响应因为它没有复制键。
### Further reading

* [Buckets](http://docs.basho.com/riak/latest/theory/concepts/Buckets/) (docs.basho.com)
* [Eventual Consistency](http://docs.basho.com/riak/latest/theory/concepts/Eventual-Consistency/) (docs.basho.com)
* [Replication](http://docs.basho.com/riak/latest/theory/concepts/Replication/) (docs.basho.com)
* [Understanding Riak's Configurable Behaviors](http://basho.com/understanding-riaks-configurable-behaviors-part-1/) (Basho blog series)
