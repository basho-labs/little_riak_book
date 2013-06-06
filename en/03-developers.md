# Developers

<aside class="sidebar"><h3>A Note on "Node"</h3>

It's worth mentioning that I use the word "node" a lot. Realistically, this means a physical/virtual server, but really, the workhorses of Riak are vnodes.

When you write to multiple vnodes, Riak will attempt to spread values to as many physical servers as possible. However, this isn't guaranteed (for example, if you have only 4 physical servers with the default `n_val` of 3, there will be a few cases where data is copied to the same server twice). You're safe conceptualizing nodes as Riak instances, and it's simpler than qualifying "vnode" all the time. If something applies specifically to a vnode, I'll mention it.
</aside>

_We're going to hold off on the details of installing Riak at the moment. If you'd like to follow along, it's easy enough to get started by following the [install documentation](http://docs.basho.com/riak/latest/) on the website (http://docs.basho.com). If not, this is a perfect section to read while you sit on a train without an Internet connection._

Developing with a Riak database is quite easy to do, once you understand some of the finer points. It is a key/value store, in the technical sense (you associate values with keys, and retrieve them using the same keys) but it offers so much more. You can embed write hooks to fire before or after a write, or index data for quick retrieval. Riak has a SOLR-based search, and lets you run MapReduce functions to extract and aggregate data across a huge cluster in a relatively short timespan. We'll show some of the bucket-specific settings developers can configure.

## Lookup

<aside class="sidebar"><h3>Supported Languages</h3>

Riak has official drivers for the following languages:
Erlang, Java, PHP, Python, Ruby

Including community-supplied drivers, supported languages are even more numerous: C/C++, Clojure, Common Lisp, Dart, Go, Groovy, Haskell, JavaScript (jQuery and NodeJS), Lisp Flavored Erlang, .NET, Perl, PHP, Play, Racket, Scala, Smalltalk.

There are also dozens of other [project-specific addons](http://docs.basho.com/riak/latest/references/Community-Developed-Libraries-and-Projects/).
</aside>

Since Riak is a KV database, the most basic commands are setting and getting values. We'll use the HTTP interface, via curl, but we could just as easily use Erlang, Ruby, Java, or any other supported language.

The basic structure of a Riak request is setting a value, reading it,
and maybe eventually deleting it. The actions are related to HTTP methods
(PUT, GET, POST, DELETE).

```bash
PUT    /riak/bucket/key
GET    /riak/bucket/key
DELETE /riak/bucket/key
```

<h4>PUT</h4>

The simplest write command in Riak is putting a value. It requires a key, value, and a bucket. In curl, all HTTP methods are prefixed with `-X`. Putting the value `pizza` into the key `favorite` under the `food` bucket is done like this:

```bash
curl -XPUT "http://localhost:8098/riak/food/favorite" \
  -H "Content-Type:text/plain" \
  -d "pizza"
```

I threw a few curveballs in there. The `-d` flag denotes the next string will be the value. We've kept things simple with the string `pizza`, declaring it as text with the proceeding line `-H 'Content-Type:text/plain'`. This defines the HTTP MIME type of this value as plain text. We could have set any value at all, be it XML or JSON---even an image or a video. Riak does not care at all what data is uploaded, so long as the object size doesn't get much larger than 4MB (a soft limit but one that it is unwise to exceed).

<h4>GET</h4>

The next command reads the value `pizza` under the bucket/key `food`/`favorite`.

```bash
curl -XGET "http://localhost:8098/riak/food/favorite"
pizza
```

This is the simplest form of read, responding with only the value. Riak contains much more information, which you can access if you read the entire response, including the HTTP header.

In `curl` you can access a full response by way of the `-i` flag. Let's perform the above query again, adding that flag.

```bash
curl -i -XGET "http://localhost:8098/riak/food/favorite"
HTTP/1.1 200 OK
X-Riak-Vclock: a85hYGBgzGDKBVIcypz/fgaUHjmdwZTImMfKcN3h1Um+LAA=
Vary: Accept-Encoding
Server: MochiWeb/1.1 WebMachine/1.9.0 (someone had painted...
Link: </riak/food>; rel="up"
Last-Modified: Wed, 10 Oct 2012 18:56:23 GMT
ETag: "1yHn7L0XMEoMVXRGp4gOom"
Date: Thu, 11 Oct 2012 23:57:29 GMT
Content-Type: text/plain
Content-Length: 5

pizza
```

The anatomy of HTTP is a bit beyond this little book, but let's look at a few parts worth noting.

<h5>Status Codes</h5>

The first line gives the HTTP version 1.1 response code `200 OK`. You may be familiar with the common website code `404 Not Found`. There are many kinds of [HTTP status codes](http://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html), and the Riak HTTP interface stays true to their intent: **1xx Informational**, **2xx Success**, **3xx Further Action**, **4xx Client Error**, **5xx Server Error**

Different actions can return different response/error codes. Complete lists can be found in the [official API docs](http://docs.basho.com/riak/latest/references/apis/).

<h5>Timings</h5>

A block of headers represents different timings for the object or the request.

* **Last-Modified** - The last time this object was modified (created or updated).
* **ETag** - An *[entity tag](http://en.wikipedia.org/wiki/HTTP_ETag)* which can be used for cache validation by a client.
* **Date** - The time of the request.
* **X-Riak-Vclock** - A logical clock which we'll cover in more detail later.

<h5>Content</h5>

These describe the HTTP body of the message (in Riak's terms, the *value*).

* **Content-Type** - The type of value, such as `text/xml`.
* **Content-Length** - The length, in bytes, of the message body.

Some other headers like `Link` will be covered later in this chapter.


<h4>POST</h4>

Similar to PUT, POST will save a value. But with POST a key is optional. All it requires is a bucket name, and it will generate a key for you.

Let's add a JSON value to represent a person under the `people` bucket. The response header is where a POST will return the key it generated for you.

```bash
curl -i -XPOST "http://localhost:8098/riak/people" \
  -H "Content-Type:application/json" \
  -d '{"name":"aaron"}'
HTTP/1.1 201 Created
Vary: Accept-Encoding
Server: MochiWeb/1.1 WebMachine/1.9.2 (someone had painted...
Location: /riak/people/DNQGJY0KtcHMirkidasA066yj5V
Date: Wed, 10 Oct 2012 17:55:22 GMT
Content-Type: application/json
Content-Length: 0
```

You can extract this key from the `Location` value. Other than not being pretty, this key is treated the same as if you defined your own key via PUT.

<h5>Body</h5>

You may note that no body was returned with the response. For any kind of write, you can add the `returnbody=true` parameter to force a value to return, along with value-related headers like `X-Riak-Vclock` and `ETag`.

```bash
curl -i -XPOST "http://localhost:8098/riak/people?returnbody=true" \
  -H "Content-Type:application/json" \
  -d '{"name":"billy"}'
HTTP/1.1 201 Created
X-Riak-Vclock: a85hYGBgzGDKBVIcypz/fgaUHjmdwZTImMfKkD3z10m+LAA=
Vary: Accept-Encoding
Server: MochiWeb/1.1 WebMachine/1.9.0 (someone had painted...
Location: /riak/people/DnetI8GHiBK2yBFOEcj1EhHprss
Link: </riak/people>; rel="up"
Last-Modified: Tue, 23 Oct 2012 04:30:35 GMT
ETag: "7DsE7SEqAtY12d8T1HMkWZ"
Date: Tue, 23 Oct 2012 04:30:35 GMT
Content-Type: application/json
Content-Length: 16

{"name":"billy"}
```

This is true for PUTs and POSTs.

<h4>DELETE</h4>

The final basic operation is deleting keys, which is similar to getting a value, but sending the DELETE method to the `url`/`bucket`/`key`.

```bash
curl -XDELETE "http://localhost:8098/riak/people/DNQGJY0KtcHMirkidasA066yj5V"
```

A deleted object in Riak is internally marked as deleted, by writing a marker known as a *tombstone*. Unless configured otherwise, another process called a *reaper* will later finish deleting the marked objects.

This detail isn't normally important, except to understand two things:

1. In Riak, a *delete* is actually a *read* and a *write*, and should be considered as such when calculating read/write ratios.
2. Checking for the existence of a key is not enough to know if an object exists. You might be reading a key after it has been deleted, so you should check for tombstone metadata.

<h4>Lists</h4>

Riak provides two kinds of lists. The first lists all *buckets* in your cluster, while the second lists all *keys* under a specific bucket. Both of these actions are called in the same way, and come in two varieties.

The following will give us all of our buckets as a JSON object.

```bash
curl "http://localhost:8098/riak?buckets=true"

{"buckets":["food"]}
```

And this will give us all of our keys under the `food` bucket.

```bash
curl "http://localhost:8098/riak/food?keys=true"
{
  ...
  "keys": [
    "favorite"
  ]
}
```

If we had very many keys, clearly this might take a while. So Riak also provides the ability to stream your list of keys. `keys=stream` will keep the connection open, returning results in chunks of arrays. When it has exhausted its list, it will close the connection. You can see the details through curl in verbose (`-v`) mode (much of that response has been stripped out below).

```bash
curl -v "http://localhost:8098/riak/food?list=stream"
...

* Connection #0 to host localhost left intact
...
{"keys":["favorite"]}
{"keys":[]}
* Closing connection #0
```

<!-- Transfer-Encoding -->

You should note that list actions should *not* be used in production (they're really expensive operations). But they are useful for development, investigations, or for running occasional analytics at off-peak hours.

## Buckets

Although we've been using buckets as namespaces up to now, they are capable of more.

Different use-cases will dictate whether a bucket is heavily written to, or largely read from. You may use one bucket to store logs, one bucket could store session data, while another may store shopping cart data. Sometimes low latency is important, while other times it's high durability. And sometimes we just want buckets to react differently when a write occurs.

<h3>Quorum</h3>

The basis of Riak's availability and tolerance is that it can read from, or write to, multiple nodes. Riak allows you to adjust these N/R/W values (which we covered under [Concepts](#practical-tradeoffs)) on a per-bucket basis.

<h4>N/R/W</h4>

N is the number of total nodes that a value should be replicated to, defaulting to 3. But we can set this `n_val` to less than the total number of nodes.

Any bucket property, including `n_val`, can be set by sending a `props` value as a JSON object to the bucket URL. Let's set the `n_val` to 5 nodes, meaning that objects written to `cart` will be replicated to 5 nodes.

```bash
curl -i -XPUT "http://localhost:8098/riak/cart" \
  -H "Content-Type: application/json" \
  -d '{"props":{"n_val":5}}'
```

You can take a peek at the bucket's properties by issuing a GET to the bucket.

*Note: Riak returns unformatted JSON. If you have a command-line tool like jsonpp (or json_pp) installed, you can pipe the output there for easier reading. The results below are a subset of all the `props` values.*

```bash
curl "http://localhost:8098/riak/cart" | jsonpp
{
  "props": {
    ...
    "dw": "quorum",
    "n_val": 5,
    "name": "cart",
    "postcommit": [],
    "pr": 0,
    "precommit": [],
    "pw": 0,
    "r": "quorum",
    "rw": "quorum",
    "w": "quorum",
    ...
  }
}
```

As you can see, `n_val` is 5. That's expected. But you may also have noticed that the cart `props` returned both `r` and `w` as `quorum`, rather than a number. So what is a *quorum*?

<h5>Symbolic Values</h5>

A *quorum* is one more than half of all the total replicated nodes (`floor(N/2) + 1`). This figure is important, since if more than half of all nodes are written to, and more than half of all nodes are read from, then you will get the most recent value (under normal circumstances).

Here's an example with the above `n_val` of 5 ({A,B,C,D,E}). Your `w` is a quorum (which is `3`, or `floor(5/2)+1`), so a PUT may respond successfully after writing to {A,B,C} ({D,E} will eventually be replicated to). Immediately after, a read quorum may GET values from {C,D,E}. Even if D and E have older values, you have pulled a value from node C, meaning you will receive the most recent value.

What's important is that your reads and writes *overlap*. As long as `r+w > n`, in the absence of *sloppy quorum* (below), you'll be able to get the newest values. In other words, you'll have a reasonable level of consistency.

A `quorum` is an excellent default, since you're reading and writing from a balance of nodes. But if you have specific requirements, like a log that is often written to, but rarely read, you might find it make more sense to wait for a successful write from a single node, but read from all of them. This affords you an overlap

```bash
curl -i -XPUT http://localhost:8098/riak/logs \
  -H "Content-Type: application/json" \
  -d '{"props":{"w":"one","r":"all"}}'
```

* `all` - All replicas must reply, which is the same as setting `r` or `w` equal to `n_val`
* `one` - Setting `r` or `w` equal to `1`
* `quorum` - A majority of the replicas must respond, that is, “half plus one”.

<h4>Sloppy Quorum</h4>

In a perfect world, a strict quorum would be sufficient for most write requests. However, at any moment a node could go down, or the network could partition, or squirrels get caught in the tubes, triggering the unavailability of a required nodes. This is known as a strict quorum. Riak defaults to what's known as a *sloppy quorum*, meaning that if any primary (expected) node is unavailable, the next available node in the ring will accept requests.

Think about it like this. Say you're out drinking with your friend. You order 2 drinks (W=2), but before they arrive, she leaves temporarily. If you were a strict quorum, you could merely refuse both drinks, since the required people (N=2) are unavailable. But you'd rather be a sloppy drunk... erm, I mean sloppy *quorum*. Rather than deny the drink, you take both, one accepted *on her behalf* (you also get to pay).

![A Sloppy Quorum](../assets/decor/drinks.png)

When she returns, you slide her drink over. This is known as *hinted handoff*, which we'll look at again in the next chapter. For now it's sufficient to note that there's a difference between the default sloppy quorum (W), and requiring a strict quorum of primary nodes (PW).

<h5>More than R's and W's</h5>

Some other values you may have noticed in the bucket's `props` object are `pw`, `pr`, and `dw`.

`pr` and `pw` ensure that many *primary* nodes are available before a read or write. Riak will read or write from backup nodes if one is unavailable, because of network partition or some other server outage. This `p` prefix will ensure that only the primary nodes are used, *primary* meaning the vnode which matches the bucket plus N successive vnodes.

(We mentioned above that `r+w > n` provides a reasonable level of consistency, violated when sloppy quorums are involved.  `pr+pw > n` allows for a much stronger assertion of consistency, although there are always scenarios involving conflicting writes or significant disk failures where that too may not be enough.)

Finally `dw` represents the minimal *durable* writes necessary for success. For a normal `w` write to count a write as successful, a vnode need only promise a write has started, with no guarantee that write has been written to disk, aka, is durable. The `dw` setting means the backend service (for example Bitcask) has agreed to write the value. Although a high `dw` value is slower than a high `w` value, there are cases where this extra enforcement is good to have, such as dealing with financial data.

<h5>Per Request</h5>

It's worth noting that these values (except for `n_val`) can be overridden *per request*.

Consider a scenario in which you have data that you find very important (say, credit card checkout), and want to help ensure it will be written to every relevant node's disk before success. You could add `?dw=all` to the end of your write.

```bash
curl -i -XPUT http://localhost:8098/riak/cart/cart1?dw=all \
  -H "Content-Type: application/json" \
  -d '{"paid":true}'
```

If any of the nodes currently responsible for the data cannot complete the request (i.e., hand off the data to the storage backend), the client will receive a failure message. This doesn't mean that the write failed, necessarily: if two of three primary vnodes successfully wrote the value, it should be available for future requests. Thus trading availability for consistency by forcing a high `dw` or `pw` value can result in unexpected behavior.

<h3>Hooks</h3>

Another utility of buckets are their ability to enforce behaviors on writes by way of hooks. You can attach functions to run either before, or after, a value is committed to a bucket.

Functions that run before a write is called precommit, and has the ability to cancel a write altogether if the incoming data is considered bad in some way. A simple precommit hook is to check if a value exists at all.

I put my custom Erlang code files under the riak installation `./custom/my_validators.erl`.

```java
-module(my_validators).
-export([value_exists/1]).

%% Object size must be greater than 0 bytes
value_exists(RiakObject) ->
  Value = riak_object:get_value(RiakObject),
  case erlang:byte_size(Value) of
    0 -> {fail, "A value sized greater than 0 is required"};
    _ -> RiakObject
  end.
```

Then compile the file.

```bash
erlc my_validators.erl
```

Install the file by informing the Riak installation of your new code via `app.config` (restart Riak).

```bash
{riak_kv,
  ...
  {add_paths, ["./custom"]}
}
```

Then you need to do set the Erlang module (`my_validators`) and function (`value_exists`) as a JSON value to the bucket's precommit array `{"mod":"my_validators","fun":"value_exists"}`.

```bash
curl -i -XPUT http://localhost:8098/riak/cart \
  -H "Content-Type:application/json" \
  -d '{"props":{"precommit":[{"mod":"my_validators","fun":"value_exists"}]}}'
```

If you try and post to the `cart` bucket without a value, you should expect a failure.

```bash
curl -XPOST http://localhost:8098/riak/cart \
  -H "Content-Type:application/json"
A value sized greater than 0 is required
```

You can also write precommit functions in JavaScript, though Erlang code will execute faster.

Post-commits are similar in form and function, albeit executed after the write has been performed. Key differences:

* The only language supported is Erlang.
* The function's return value is ignored, thus it cannot cause a failure message to be sent to the client.

## Entropy

Entropy is a byproduct of eventual consistency. In other words: although eventual consistency says a write will replicate to other nodes in time, there can be a bit of delay during which all nodes do not contain the same value.

That difference is *entropy*, and so Riak has created several *anti-entropy* strategies (abbreviated as *AE*). We've already talked about how an R/W quorum can deal with differing values when write/read requests overlap at least one node. Riak can repair entropy, or allow you the option to do so yourself.

Riak has two basic strategies to address conflicting writes.

<h3>Last Write Wins</h3>

The most basic, and least reliable, strategy for curing entropy is called *last write wins*. It's the simple idea that the last write based on a node's system clock will overwrite an older one. This is currently the default behavior in Riak (by virtue of the `allow_mult` property defaulting to `false`). You can also set the `last_write_wins` property to `true`, which improves performance by never retaining vector clock history.

Realistically, this exists for speed and simplicity, when you really don't care about true order of operations, or the possibility of losing data. Since it's impossible to keep server clocks truly in sync (without the proverbial geosynchronized atomic clocks), this is a best guess as to what "last" means, to the nearest millisecond.

<h3>Vector Clocks</h3>

As we saw under [Concepts](#practical-tradeoffs), *vector clocks* are Riak's way of tracking a true sequence of events of an object. Let's take a look at using vector clocks to allow for a more sophisticated conflict resolution approach than simply retaining the last-written value.

<h4>Siblings</h4>

*Siblings* occur when you have conflicting values, with no clear way for Riak to know which value is correct. Riak will try to resolve these conflicts itself if the `allow_mult` parameter is configured to `false`, but you can instead ask Riak to retain siblings to be resolved by the client if you set `allow_mult` to `true`.

```bash
curl -i -XPUT http://localhost:8098/riak/cart \
  -H "Content-Type:application/json" \
  -d '{"props":{"allow_mult":true}}'
```

Siblings arise in a couple cases.

1. A client writes a value using a stale (or missing) vector clock.
2. Two clients write at the same time with the same vector clock value.

We used the second scenario to manufacture a conflict in the previous chapter when we introduced the concept of vector clocks, and we'll do so again here.

<h4>Creating an Example Conflict</h4>

Imagine we create a shopping cart for a single refrigerator, but several people in a household are able to order food for it. Because losing orders would result in an unhappy household, Riak is configured with `allow_mult=true`.

First Casey (a vegan) places 10 orders of kale in the cart.

Casey writes `[{"item":"kale","count":10}]`.

```bash
curl -i -XPUT http://localhost:8098/riak/cart/fridge-97207?returnbody=true \
  -H "Content-Type:application/json" \
  -d '[{"item":"kale","count":10}]'
HTTP/1.1 200 OK
X-Riak-Vclock: a85hYGBgzGDKBVIcypz/fgaUHjmTwZTImMfKsMKK7RRfFgA=
Vary: Accept-Encoding
Server: MochiWeb/1.1 WebMachine/1.9.0 (someone had painted...
Link: </riak/cart>; rel="up"
Last-Modified: Thu, 01 Nov 2012 00:13:28 GMT
ETag: "2IGTrV8g1NXEfkPZ45WfAP"
Date: Thu, 01 Nov 2012 00:13:28 GMT
Content-Type: application/json
Content-Length: 28

[{"item":"kale","count":10}]
```

Note the opaque vector clock (via the `X-Riak-Vclock` header) returned by Riak. That same value will be returned with any read request issued for that key until another write occurs.

His roommate Mark, reads the order and adds milk. In order to allow Riak to track the update history properly, Mark includes the most recent vector clock with his PUT.

Mark writes `[{"item":"kale","count":10},{"item":"milk","count":1}]`.

```bash
curl -i -XPUT http://localhost:8098/riak/cart/fridge-97207?returnbody=true \
  -H "Content-Type:application/json" \
  -H "X-Riak-Vclock:a85hYGBgzGDKBVIcypz/fgaUHjmTwZTImMfKsMKK7RRfFgA="" \
  -d '[{"item":"kale","count":10},{"item":"milk","count":1}]'
HTTP/1.1 200 OK
X-Riak-Vclock: a85hYGBgzGDKBVIcypz/fgaUHjmTwZTIlMfKcMaK7RRfFgA=
Vary: Accept-Encoding
Server: MochiWeb/1.1 WebMachine/1.9.0 (someone had painted...
Link: </riak/cart>; rel="up"
Last-Modified: Thu, 01 Nov 2012 00:14:04 GMT
ETag: "62NRijQH3mRYPRybFneZaY"
Date: Thu, 01 Nov 2012 00:14:04 GMT
Content-Type: application/json
Content-Length: 54

[{"item":"kale","count":10},{"item":"milk","count":1}]
```

If you look closely, you'll notice that the vector clock changed with the second write request

* <code>a85hYGBgzGDKBVIcypz/fgaUHjmTwZTI<strong>mMfKsMK</strong>K7RRfFgA=</code> (after the write by Casey)
* <code>a85hYGBgzGDKBVIcypz/fgaUHjmTwZTI<strong>lMfKcMa</strong>K7RRfFgA=</code> (after the write by Mark)

Now let's consider a third roommate, Andy, who loves almonds. Before Mark updates the shared cart with milk, Andy retrieved Casey's kale order and appends almonds. As with Mark, Andy's update includes the vector clock as it existed after Casey's original write.

Andy writes `[{"item":"kale","count":10},{"item":"almonds","count":12}]`.

```bash
curl -i -XPUT http://localhost:8098/riak/cart/fridge-97207?returnbody=true \
  -H "Content-Type:application/json" \
  -H "X-Riak-Vclock:a85hYGBgzGDKBVIcypz/fgaUHjmTwZTImMfKsMKK7RRfFgA="" \
  -d '[{"item":"kale","count":10},{"item":"almonds","count":12}]'
HTTP/1.1 300 Multiple Choices
X-Riak-Vclock: a85hYGBgzGDKBVIcypz/fgaUHjmTwZTInMfKoG7LdoovCwA=
Vary: Accept-Encoding
Server: MochiWeb/1.1 WebMachine/1.9.0 (someone had painted...
Last-Modified: Thu, 01 Nov 2012 00:24:07 GMT
ETag: "54Nx22W9M7JUKJnLBrRehj"
Date: Thu, 01 Nov 2012 00:24:07 GMT
Content-Type: multipart/mixed; boundary=Ql3O0enxVdaMF3YlXFOdmO5bvrs
Content-Length: 491


--Ql3O0enxVdaMF3YlXFOdmO5bvrs
Content-Type: application/json
Link: </riak/cart>; rel="up"
Etag: 62NRijQH3mRYPRybFneZaY
Last-Modified: Thu, 01 Nov 2012 00:14:04 GMT

[{"item":"kale","count":10},{"item":"milk","count":1}]
--Ql3O0enxVdaMF3YlXFOdmO5bvrs
Content-Type: application/json
Link: </riak/cart>; rel="up"
Etag: 7kfvPXisoVBfC43IiPKYNb
Last-Modified: Thu, 01 Nov 2012 00:24:07 GMT

[{"item":"kale","count":10},{"item":"almonds","count":12}]
--Ql3O0enxVdaMF3YlXFOdmO5bvrs--
```

Whoa! What's all that?

Since there was a conflict between what Mark and Andy set the fridge value to be, Riak kept both values.

<h4>VTag</h4>

Since we're using the HTTP client, Riak returned a `300 Multiple Choices` code with a `multipart/mixed` MIME type. It's up to you to parse the results (or you can request a specific value by its Etag, also called a Vtag).

Issuing a plain get on the `/cart/fridge-97207` key will also return the vtags of all siblings.

```
curl http://localhost:8098/riak/cart/fridge-97207
Siblings:
62NRijQH3mRYPRybFneZaY
7kfvPXisoVBfC43IiPKYNb
```

What can you do with this tag? Namely, you request the value of a specific sibling by its `vtag`. To get the first sibling in the list (Mark's milk):

```bash
curl http://localhost:8098/riak/cart/fridge-97207?vtag=62NRijQH3mRYPRybFneZaY
[{"item":"kale","count":10},{"item":"milk","count":1}]
```

If you want to retrieve all sibling data, tell Riak that you'll accept the multipart message by adding `-H "Accept:multipart/mixed"`.

```bash
curl http://localhost:8098/riak/cart/fridge-97207 \
  -H "Accept:multipart/mixed"
```

<aside class="sidebar"><h3>Use-Case Specific?</h3>

When siblings are created, it's up to the application to know how to deal
with the conflict. In our example, do we want to accept only one of the
orders? Should we remove both milk and almonds and only keep the kale?
Should we calculate the cheaper of the two and keep the cheapest option?
Should we merge all of the results into a single order? This is why we asked
Riak not to resolve this conflict automatically... we want this flexibility.
</aside>

<h4>Resolving Conflicts</h4>

When we have conflicting writes, we want to resolve them. Since that problem is typically *use-case specific*, Riak defers it to us, and our application must decide how to proceed.

For our example, let's merge the values into a single result set, taking the larger *count* if the *item* is the same. When done, write the new results back to Riak with the vclock of the multipart object, so Riak knows you're resolving the conflict, and you'll get back a new vector clock.

Successive reads will receive a single (merged) result.

```bash
curl -i -XPUT http://localhost:8098/riak/cart/fridge-97207?returnbody=true \
  -H "Content-Type:application/json" \
  -H "X-Riak-Vclock:a85hYGBgzGDKBVIcypz/fgaUHjmTwZTInMfKoG7LdoovCwA=" \
  -d '[{"item":"kale","count":10},{"item":"milk","count":1},\
      {"item":"almonds","count":12}]'
```

<h3>Last write wins vs. siblings</h3>

Your data and your business needs will dictate which approach to conflict resolution is appropriate. You don't need to choose one strategy globally; instead, feel free to take advantage of Riak's buckets to specify which data uses siblings and which blindly retains the last value written.

A quick recap of the two configuration values you'll want to set:

* `allow_mult` defaults to `false`, which means that the last write wins.
* Setting `allow_mult` to `true` instructs Riak to retain conflicting writes as siblings.
* `last_write_wins` defaults to `false`, which (perhaps counter-intuitively) still can mean that the behavior is last write wins: `allow_mult` is the key parameter for the behavioral toggle.
* Setting `last_write_wins` to true will optimize writes by assuming that previous vector clocks have no inherent value.
* Setting both `allow_mult` and `last_write_wins` to `true` is unsupported and will result in undefined behavior.

<h3>Read Repair</h3>

When a successful read happens, but not all replicas agree upon the value, this triggers a *read repair*. This means that Riak will update the replicas with the most recent value. This can happen either when an object is not found (the vnode has no copy) or a vnode contains an older value (older means that it is an ancestor of the newest vector clock). Unlike `last_write_wins` or manual conflict resolution, read repair is (obviously, I hope, by the name) triggered by a read, rather than a write.

If your nodes get out of sync (for example, if you increase the `n_val` on a bucket), you can force read repair by performing a read operation for all of that bucket's keys. They may return with `not found` the first time, but later reads will pull the newest values.

<h3>Active Anti-Entropy (AAE)</h3>

Although resolving conflicting data during get requests via read repair is sufficient for most needs, data which is never read can eventually be lost as nodes fail and are replaced.

With Riak 1.3, Basho introduced active anti-entropy to proactively identify and repair inconsistent data. This feature is also helpful for recovering data loss in the event of disk corruption or administrative error.

The overhead for this functionality is minimized by maintaining sophisticated hash trees ("Merkle trees") which make it easy to compare data sets between vnodes, but if desired the feature can be disabled.

## Querying

So far we've only dealt with key-value lookups. The truth is, key-value is a pretty powerful mechanism that spans a spectrum of use-cases. However, sometimes we need to lookup data by value, rather than key. Sometimes we need to perform some calculations, or aggregations, or search.

<h3>Secondary Indexing (2i)</h3>

A *secondary index* (2i) is a data structure that lowers the cost of
finding non-key values. Like many other databases, Riak has the
ability to index data. However, since Riak has no real knowledge of
the data it stores (they're just binary values), it uses metadata to
index defined by a name pattern to be either integers or binary values.

If your installation is configured to use 2i (shown in the next chapter),
simply writing a value to Riak with the header will be indexes,
provided it's prefixed by `X-Riak-Index-` and suffixed by `_int` for an
integer, or `_bin` for a string.

```bash
curl -i -XPUT http://localhost:8098/riak/people/casey \
  -H "Content-Type:application/json" \
  -H "X-Riak-Index-age_int:31" \
  -H "X-Riak-Index-fridge_bin:fridge-97207" \
  -d '{"work":"rodeo clown"}'
```

Querying can be done in two forms: exact match and range. Add a couple more people and we'll see what we get: `mark` is `32`, and `andy` is `35`, they both share `fridge-97207`.

What people own `fridge-97207`? It's a quick lookup to receive the
keys that have matching index values.

```bash
curl http://localhost:8098/buckets/people/index/fridge_bin/fridge-97207
{"keys":["mark","casey","andy"]}
```

With those keys it's a simple lookup to get the bodies.

The other query option is an inclusive ranged match. This finds all
people under the ages of `32`, by searching between `0` and `32`.

```bash
curl http://localhost:8098/buckets/people/index/age_int/0/32
{"keys":["mark","casey"]}
```

That's about it. It's a basic form of 2i, with a decent array of utility.

<h3>MapReduce/Link Walking</h3>

MapReduce is a method of aggregating large amounts of data by separating the
processing into two phases, map and reduce, that themselves are executed
in parts. Map will be executed per object to convert/extract some value,
then those mapped values will be reduced into some aggregate result. What
do we gain from this structure? It's predicated on the idea that it's cheaper
to move the algorithms to where the data lives, than to transfer massive
amounts of data to a single server to run a calculation.

This method, popularized by Google, can be seen in a wide array of NoSQL
databases. In Riak, you execute a MapReduce job on a single node, which
then propagates to the other nodes. The results are mapped and reduced,
then further reduced down to the calling node and returned.

![MapReduce Returning Name Char Count](../assets/mapreduce.svg)

Let's assume we have a bucket for log values that stores messages
prefixed by either INFO or ERROR. We want to count the number of INFO
logs that contain the word "cart".

```bash
LOGS=http://localhost:8098/riak/logs
curl -XPOST $LOGS -d "INFO: New user added"
curl -XPOST $LOGS -d "INFO: Kale added to shopping cart"
curl -XPOST $LOGS -d "INFO: Milk added to shopping cart"
curl -XPOST $LOGS -d "ERROR: shopping cart cancelled"
```

MapReduce jobs can be either Erlang or JavaScript code. This time we'll go the
easy route and write JavaScript. You execute MapReduce by posting JSON to the
`/mapred` path.

```bash
curl -XPOST "http://localhost:8098/mapred" \
  -H "Content-Type: application/json" \
  -d @- \
<<EOF
{
  "inputs":"logs",
  "query":[{
    "map":{
      "language":"javascript",
      "source":"function(riakObject, keydata, arg) {
        var m = riakObject.values[0].data.match(/^INFO.*cart/);
        return [(m ? m.length : 0 )];
      }"
    },
    "reduce":{
      "language":"javascript",
      "source":"function(values, arg){
        return [values.reduce(
          function(total, v){ return total + v; }, 0)
        ];
      }"
    }
  }]
}
EOF
```

The result should be `[2]`, as expected. Both map and reduce phases should
always return an array. The map phase receives a single riak object, while
the reduce phase received an array of values, either the result of multiple
map function outputs, or of multiple reduce outputs. I probably cheated a
bit by using JavaScript's `reduce` function to sum the values, but, well,
welcome to the world of thinking in terms of MapReduce!

<h4>Key Filters</h4>

Besides executing a map function against every object in a bucket, you
can reduce the scope by using *key filters*. Just as it sounds, they
are a way of only including those objects that match a pattern...
it filters out certain keys.

Rather than passing in a bucket name as a value for `inputs`, instead
we pass it a JSON object containing the `bucket` and `key_filters`.
The `key_filters` get an array describing how to transform then test each key
in the bucket. Any keys that match the predicate will be passed into the
map phase, all others are just filtered out.

To get all keys in the `cart` bucket that end with a number greater than 97000,
you could tokenize the keys on `-` (remember we used `fridge-97207`) and
keep the second half of the string, convert it to an integer, then compare
that number to be greater than 97000.

```
"inputs":{
  "bucket":"cart",
  "key_filters":[["tokenize", "-", 2],["string_to_int"],["greater_than",97000]]
}
```

It would look like this to have the mapper just return matching object keys. Pay
special attention to the `map` function, and lack of `reduce`.

```bash
curl -XPOST http://localhost:8098/mapred \
  -H "Content-Type: application/json" \
  -d @- \
<<EOF
{
  "inputs":{
    "bucket":"cart",
    "key_filters":[
      ["tokenize", "-", 2],
      ["string_to_int"],
      ["greater_than",97000]
    ]
  },
  "query":[{
    "map":{
      "language":"javascript",
      "source":"function(riakObject, keydata, arg) {
        return [riakObject.key];
      }"
    }
  }]
}
EOF
```

<h4>MR + 2i</h4>

Another option when using MapReduce is to combine it with secondary indexes.
You can pipe the results of a 2i query into a MapReducer, simply specify the
index you wish to use, and either a `key` for an index lookup, or `start` and
`end` values for a ranged query.

```json
    ...
    "inputs":{
       "bucket":"people",
       "index": "age_int",
       "start": 18,
       "end":   32
    },
    ...
```

<h4>Link Walking</h4>

Conceptually, a link is a one-way relationship from one object to another.
*Link walking* is a convenient query option for retrieving data when you start
with the object linked from.

Let's add a link to our people, by setting `casey` as the brother of `mark`
using the HTTP header `Link`.

```bash
curl -XPUT http://localhost:8098/riak/people/mark \
  -H "Content-Type:application/json" \
  -H "Link: </riak/people/casey>; riaktag=\"brother\""
```

With a Link in place, now it's time to walk it. Walking is like a normal
request, but with the suffix of `/[bucket],[riaktag],[keep]`. In other words,
the *bucket* a possible link points to, the value of a *riaktag*, and whether to
*keep* the results of this phase (only useful when chaining link walks). Any combination
of these query values can be set to a wildcard _, meaning you want to match anything.

```bash
curl http://localhost:8098/riak/people/mark/people,brother,_

--8wuTE7VSpvHlAJo6XovIrGFGalP
Content-Type: multipart/mixed; boundary=991Bi7WVpjYAGUwZlMfJ4nPJROw

--991Bi7WVpjYAGUwZlMfJ4nPJROw
X-Riak-Vclock: a85hYGBgzGDKBVIcypz/fgZMzorIYEpkz2NlWCzKcYovCwA=
Location: /riak/people/casey
Content-Type: application/json
Link: </riak/people>; rel="up"
Etag: Wf02eljDiBa5q5nSbTq2s
Last-Modified: Fri, 02 Nov 2012 10:00:03 GMT
x-riak-index-age_int: 31
x-riak-index-fridge_bin: fridge-97207

{"work":"rodeo clown"}
--991Bi7WVpjYAGUwZlMfJ4nPJROw--

--8wuTE7VSpvHlAJo6XovIrGFGalP--
```

Even without returning the Content-Type, this kind of body should look familiar.
Link walking always returns a `multipart/mixed`, since a single key can
contain any number of links, meaning any number of objects returned.

It gets crazier. You can actually chain together link walks, which will follow the
a followed link. If `casey` has links, they can be followed by tacking another link
triplet on the end, like so:

```bash
curl http://localhost:8098/riak/people/mark/people,brother,0/_,_,_
```

Now it may not seem so from what we've seen, but link walking is a specialized
case of MapReduce.

There is another phase of a MapReduce query called "link". Rather than
executing a function, however, it only requires the same configuration
that you pass through the shortcut URL query.

```json
    ...
    "query":[{
      "link":{
        "bucket":"people",
        "tag":   "brother",
        "keep":  false
      }
    }]
    ...
```

As we've seen, MapReduce in Riak is a powerful way of pulling data out of an
otherwise straight key/value store. But we have one more method of finding
data in Riak.


<aside class="sidebar"><h3>What Happened to Riak Search?</h3>

If you have used Riak before, or have some older documentation,
you may wonder what the difference is between Riak Search and Yokozuna.

In an attempt to make Riak Search user friendly, it was originally developed
with a "Solr like" interface. Sadly, due to the complexity of building
distributed search engines, it was woefully incomplete. Basho decided that,
rather than attempting to maintain parity with Solr, a popular and featureful
search engine in its own right, it made more sense to integrate the two.
</aside>

<h3>Search (Yokozuna)</h3>

*Note: This is covering a project still under development. Changes are to be
expected, so please refer to the
[project page](https://github.com/rzezeski/yokozuna) for the most recent
information.*

Yokozuna is an extension to Riak that lets you perform searches to find
data in a Riak cluster. Unlike the original Riak Search, Yokozuna leverages
distributed Solr to perform the inverted indexing and management of
retrieving matching values.

Before using Yokozuna, you'll have to have it installed and a bucket set
up with an index (these details can be found in the next chapter).

The simplest example is a full-text search. Here we add `ryan` to the
`people` table (with a default index).

```bash
curl -XPUT http://localhost:8098/riak/people/ryan \
  -H "Content-Type:text/plain" \
  -d "Ryan Zezeski"
```

To execute a search, request `/search/[bucket]` along with any distributed [Solr parameters](http://wiki.apache.org/solr/CommonQueryParameters). Here we
query for documents that contain a word starting with `zez`, request the
results to be in json format (`wt=json`), only return the Riak key
(`fl=_yz_rk`).

```bash
curl "http://localhost:8098/search/people?wt=json&\
      omitHeader=true&fl=_yz_rk&q=zez*" | jsonpp
{
  "response": {
    "numFound": 1,
    "start": 0,
    "maxScore": 1.0,
    "docs": [
      {
        "_yz_rk": "ryan"
      }
    ]
  }
}
```

With the matching `_yz_rk` keys, you can retrieve the bodies with a simple
Riak lookup.

Yokozuna supports Solr 4.0, which includes filter queries, ranges, page scores,
start values and rows (the last two are useful for pagination). You can also
receive snippets of matching
[highlighted text](http://wiki.apache.org/solr/HighlightingParameters)
(`hl`,`hl.fl`), which is useful for building a search engine (and something
we use for [search.basho.com](http://search.basho.com)).


<h4>Tagging</h4>

Another useful feature of Solr and Yokozuna is the tagging of values. Tagging
values give additional context to a Riak value. The current implementation
requires all tagged values begin with `X-Riak-Meta`, and be listed under
a special header named `X-Riak-Meta-yz-tags`.

```bash
curl -XPUT "http://localhost:8098/riak/people/dave" \
  -H "Content-Type:text/plain" \
  -H "X-Riak-Meta-yz-tags: X-Riak-Meta-nickname_s" \
  -H "X-Riak-Meta-nickname_s:dizzy" \
  -d "Dave Smith"
```

To search by the `nickname_s` tag, just prefix the query string followed
by a colon.

```bash
curl "http://localhost:8098/search/people?wt=json&\
      omitHeader=true&q=nickname_s:dizzy" | jsonpp
{
  "response": {
    "numFound": 1,
    "start": 0,
    "maxScore": 1.4054651,
    "docs": [
      {
        "nickname_s": "dizzy",
        "id": "dave_25",
        "_yz_ed": "20121102T215100 dave m7psMIomLMu/+dtWx51Kluvvrb8=",
        "_yz_fpn": "23",
        "_yz_node": "dev1@127.0.0.1",
        "_yz_pn": "25",
        "_yz_rk": "dave",
        "_version_": 1417562617478643712
      }
    ]
  }
}
```

Notice that the `docs` returned also contain `"nickname_s":"dizzy"` as a
value. All tagged values will be returned on matching results.

*Expect more features to appear as Yokozuna gets closer to a final release.*

## Wrapup

Riak is a distributed data store with several additions to improve upon the
standard key-value lookups, like specifying replication values. Since values
in Riak are opaque, many of these methods either: require custom code to
extract and give meaning to values,
such as *MapReduce*; or allow for header metadata to provide an added
descriptive dimension to the object, such as *secondary indexes*, *link
walking*, or *search*.

Next we'll peek further under the hood, and see how to set up and manage
a cluster of your own, and what you should know.
