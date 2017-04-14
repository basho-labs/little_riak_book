# Notes

# 笔记

## A Short Note on RiakCS    

## 关于RiakCS的简述

*Riak CS* is Basho's open-source extension to Riak that allows your cluster to act as
a remote object storage mechanism, comparable to (and compatible with) Amazon's
S3. There are several reasons why you may want to host your own cloud storage mechanism
(security, legal reasons, you already own lots of hardware, cheaper at scale).
Riak CS is not covered in this short book, but I may certainly be bribed to
write one.

Riak CS是Basho对Riak的开源的扩展，Riak允许你的集群以远程对象的存储机制处理，相当于（且兼容于）亚马逊的S3。
有几个原因可能会使你想要建立自己的云存储机制（安全、法律、你已拥有了大量硬件、扩展更加便宜）。
Riak CS没有包括在这本简书中，但是我可能被收买写一本关于它的书。

## 关于MDC的简述

*MDC*, or Multi-Datacenter, is a commercial extension to Riak provided by Basho.
While the documentation is freely available, the source code is not. If you reach
a scale where keeping multiple Riak clusters in sync on a local or global scale is
necessary, I would recommend considering this option.

多数据中心（MDC，Multi-Datacenter）是Basho对于Riak的一个商业性的扩展。尽管相关文档是可以免费获得的，但源码却不能免费获取。
如果你达到一定规模，保持多个Riak集群在本地或全局同步是必要的，我建议考虑此选项。

## Locks, a cautionary tale  

## 锁，一个警示性的故事

While assembling the *Writing Applications* chapter, I (John) tried to develop a data model
that would allow for reliable locking without strong consistency. While that attempt failed,
I thought it would be better to include it to illustrate the complexities of coping
with eventual consistency than to throw it away entirely.

在构思“编写应用程序”这一章时，我（Jhon）试图开发一个不具有强一致性的可靠的锁数据模型。
尽管那一次尝试失败了，但我认为总结出这个模型来描述最终一致性的复杂程度要比完全地抛弃这个模型好得多。

Basic premise: multiple workers may be assigned datasets to process,
but each dataset should be assigned to no more than one worker.

基本前提：多个Worker可能会被分配多个数据集进行处理，但每个数据集只能分配到一个Worker。

In the absence of strong consistency, the best an application can do
is to use the `pr` and `pw` (primary read and primary write) parameters with
a value of `quorum` or `n_val`.

在没有强一致性的情况下，一个应用能做到的最好的就是使用带有‘quorum’或者‘n_val’值的‘pr’（primary read）和‘pw’（primary write）参数。

Common features to all of these models:

这些模型的普遍特点：

* Lock for any given dataset is a known key
* Value is a unique identifier for the worker

* 给任何一个数据集的锁是一个已知的键。
* 对于每个Worker而言，值是一个独一无二的标识。

### Lock, a first draft  

### 锁，第一篇

__Sequence__

__顺序__

Bucket: `allow_mult=false`

桶：`allow_mult=false`

1. Worker reads with `pr=quorum` to determine whether a lock exists
2. If it does, move on to another dataset
3. If it doesn't, create a lock with `pw=quorum`
4. Process dataset to completion
5. Remove the lock

1. Worker读取`pr=quorum`来检查是否存在一个锁。
2. 如果存在，则移动到下一个数据集。
3. 如果不存在，则用`pw=quorum`创建一个锁。
4. 处理数据集完成操作。
5. 移除锁。

__Failure scenario__

__失败情况__

1. Worker #1 reads the non-existent lock
2. Worker #2 reads the non-existent lock
3. Worker #2 writes its ID to the lock
4. Worker #2 starts processing the dataset
5. Worker #1 writes its ID to the lock
6. Worker #1 starts processing the dataset

1. Worker #1 读取了不存在的锁。
2. Worker #2 读取了不存在的锁。
3. Worker #2 将它的ID写入到锁中。
4. Worker #2 开始处理数据集。
5. Worker #1 将它的ID写入到锁中。
6. Worker #1 开始处理数据集。

### Lock, a second draft

### 锁，第二篇

Bucket: `allow_mult=false`

桶：`allow_mult=false`

__Sequence__

__顺序__

1. Worker reads with `pr=quorum` to determine whether a lock exists
2. If it does, move on to another dataset
3. If it doesn't, create a lock with `pw=quorum`
4. Read lock again with `pr=quorum`
5. If the lock exists with another worker's ID, move on to another
   dataset
6. Process dataset to completion
7. Remove the lock

1. Worker读取`pr=quorum`来检查是否存在一个锁。
2. 如果存在，则移动到另一个数据集。
3. 如果不存在，则通过`pw=quorum`创建一个锁。
4. 再一次通过`pr=quorum`读取锁。
5. 如果锁存在且被另一个Worker的ID标识，则移动到另一个数据集。
6. 处理数据集完成操作。
7. 移除锁。

__Failure scenario__

__失败情况__

1. Worker #1 reads the non-existent lock
2. Worker #2 reads the non-existent lock
3. Worker #2 writes its ID to the lock
4. Worker #2 reads the lock and sees its ID
5. Worker #1 writes its ID to the lock
6. Worker #1 reads the lock and sees its ID
7. Both workers process the dataset

1. Worker #1 读取了不存在的锁。
2. Worker #2 读取了不存在的锁。
3. Worker #2 将它的ID写入到锁中。
4. Worker #2 读取锁并看到了它的ID。
5. Worker #1 将它的ID写入到锁中。
6. Worker #1 读取锁并看到了它的ID。
7. 所有的Worker都处理数据集

If you've done any programming with threads before, you'll recognize
this as a common problem with non-atomic lock operations.

如果你以前使用过线程编程，你就会意识到这在使用非原子锁操作时存在的一个常见的问题。

### Lock, a third draft

### 锁，第三篇

Bucket: `allow_mult=true`

桶： `allow_mult=true`

__Sequence__

__顺序__

1. Worker reads with `pr=quorum` to determine whether a lock exists
2. If it does, move on to another dataset
3. If it doesn't, create a lock with `pw=quorum`
4. Read lock again with `pr=quorum`
5. If the lock exists with another worker's ID **or** the lock
contains siblings, move on to another dataset
6. Process dataset to completion
7. Remove the lock

1. Worker读取`pr=quorum`来检查是否存在一个锁。
2. 如果存在，则移动到另一个数据集。
3. 如果不存在，则通过`pw=quorum`创建一个锁。
4. 再一次通过`pr=quorum`读取锁。
5. 如果锁存在且被另一个Worker的ID标识或者这个锁包含兄弟锁，则移动到另一个数据集。
6. 处理数据集完成操作。
7. 移除锁。

__Failure scenario__

__失败情况__

1. Worker #1 reads the non-existent lock
2. Worker #2 reads the non-existent lock
3. Worker #2 writes its ID to the lock
4. Worker #1 writes its ID to the lock
5. Worker #1 reads the lock and sees a conflict
6. Worker #2 reads the lock and sees a conflict
7. Both workers move on to another dataset

1. Worker #1 读取了不存在的锁。
2. Worker #2 读取了不存在的锁。
3. Worker #2 将它的ID写入到锁中。
4. Worker #1 将它的ID写入到锁中。
5. Worker #1 读取锁并看到了一个冲突。
6. Worker #2 读取锁并看到了一个冲突。
7. 所有的Worker都移动到另一个数据集。

### Lock, a fourth draft

### 锁，第四篇

Bucket: `allow_mult=true`

桶： `allow_mult=true`

__Sequence__

__顺序__

1. Worker reads with `pr=quorum` to determine whether a lock exists
2. If it does, move on to another dataset
3. If it doesn't, create a lock with `pw=quorum` and a timestamp
4. Read lock again with `pr=quorum`
5. If the lock exists with another worker's ID **or** the lock
contains siblings **and** its timestamp is not the earliest, move on
to another dataset
6. Process dataset to completion
7. Remove the lock

1. Worker读取`pr=quorum`来检查是否存在一个锁。
2. 如果存在，则移动到另一个数据集。
3. 如果不存在，则通过`pw=quorum`创建一个锁和一个时间戳。
4. 再一次通过`pr=quorum`读取锁。
5. 如果锁存在且被另一个Worker的ID标识或者这个锁包含兄弟锁并且它的时间戳不是最早的，则移动到另一个数据集。
6. 处理数据集完成操作。
7. 移除锁。

__Failure scenario__

__失败情况__

1. Worker #1 reads the non-existent lock
2. Worker #2 reads the non-existent lock
3. Worker #2 writes its ID and timestamp to the lock
4. Worker #2 reads the lock and sees its ID
5. Worker #2 starts processing the dataset
6. Worker #1 writes its ID and timestamp to the lock
7. Worker #1 reads the lock and sees its ID with the lowest timestamp
8. Worker #1 starts processing the dataset

1. Worker #1 读取了不存在的锁。
2. Worker #2 读取了不存在的锁。
3. Worker #2 将它的ID和时间戳写入到锁中。
4. Worker #2 读取锁并看到了它的ID。
5. Worker #2 开始处理数据集。
6. Worker #1 将它的ID和时间戳写入到锁中。
7. Worker #1 读取锁并看到了一个冲突和最晚的时间戳。
8. Worker #1 开始处理数据集。

At this point I may hear you grumbling: clearly worker #2 would have
the lower timestamp because it attempted its write first, and thus #1
would skip the dataset and try another one.

针对这一点你可能会抱怨：很明显Worker #2 有更晚的时间戳，因为它是第一次尝试写入的，因此 #1
应该跳过这个数据集去尝试另一个数据集。

*Even if* both workers are running on the same server (and thus
*probably* have timestamps that can be compared)[^clock-comparisons],
perhaps worker #1 started its write earlier but contacted an overloaded cluster
member that took longer to process the request.

即使所有的Worker都运行在同样的服务器上（因此时间戳可能被用来比较）[^时钟比较]，
Worker #1 也可能会先进行写入操作，因为联系一个重载的集群成员会花费较长的时间来处理请求。

[^clock-comparisons]: An important part of any distributed systems
discussion is the fact that clocks are inherently untrustworthy, and
thus calling any event the "last" to occur is an exercise in faith:
faith that a system clock wasn't set backwards in time by  `ntpd` or an
impatient system administrator, faith that all clocks involved are in
perfect sync.

[^时钟比较]: 在任何分布式系统中讨论的一个重要事实是 时钟原本就不值得信任，因此再调用任何事件时，
最后一个发生是一个相对的概念：这个概念是指一个系统的时钟不能及时的通过`ntpd`或者一个不耐烦的系统管理员来进行回退设置。

    And, to be clear, perfect synchronization of clocks across
    multiple systems is unattainable. Google is attempting to solve
    this by purchasing lots of atomic and GPS clocks at great expense,
    and even that only narrows the margin of error.

同时，显而易见地，多个系统的时钟完全同步是个不能达到的。Google企图通过斥巨资购买大量原子和GPS时钟来解决这个问题。
及时那么做只能是缩小误差范围。

The same failure could occur if, instead of using timestamps for
comparison purposes, the ID of each worker was used for comparison
purposes. All it takes is for one worker to read its own write before
another worker's write request arrives.

不通过使用时间戳来比较，而是使用每个Worker的ID进行比较的话，会发生同样的错误。
完成比较所需要的就是一个Worker能够在另一个Worker写的请求到来之前读到它写的内容。

### Conclusion

### 结论

We can certainly come up with algorithms that limit the number of
times that multiple workers tackle the same job, but I have yet to
find one that guarantees exclusion.

我们肯定能想出算法来限制多个Worker处理同样工作消耗时间的大小，但是我还没找到一个算法能够保证例外。

What I found surprising about this exercise is that none of the
failure scenarios required any of the odder edge conditions that can
cause unexpected outcomes. For example, `pw=quorum` writes will return
an error to the client if 2 of the primary servers are not available,
but the value will *still* be written to the 3rd server and 2 fallback
servers. Predicting what will happen the next time someone tries to
read the key is challenging.

让我对这次练习感到惊讶的是没有失败情况需要任何的能导致意外输出的特殊的临界情况。
例如，如果主要服务器中的两个不能连接，那么`pw=quorum`写入操作会返回给客户端一个错误，
但是这个值仍然能被写入到第三个服务器和第二个备份服务器中。猜想下一次某个人尝试读取这个键的结果是一个挑战。

None of these algorithms required deletion of a value, but that is
particularly fraught with peril. It's not difficult to construct
scenarios in which deleted values reappear if servers are temporarily
unavailable during the deletion request.

这个算法中没有一个算法需要删除值，但是这是极其危险的。
如果在删除请求期间服务器暂时不可用，则删除值重新出现的场景不难构建。
