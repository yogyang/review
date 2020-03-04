---
marp: false
# theme: uncover
# _class: invert
---
### The Dataflow Model

A Practical Approach to Balancing
**Correctness, Latency, and Cost** in Massive-Scale,
**Unbounded, Out-of-Order** Data Processing

---

### Bounded && Unbounded
![Bounded](http://streamingbook.net/static/images/figures/stsy_0102.png)

> Batch 
> execute once
> Correct Correctness

---
### Unbounded: Batch
No ending for Data, Reptead Runs of batch job 
-  Cut Unbounded to Bounded: Every 2 Minutes

Senarios:
-  Fixed windows: Agg(sum(count))
   ![fixed](http://streamingbook.net/static/images/figures/stsy_0103.png)
   
---
### Unbounded: Batch

- Session: Agg(sum(count)) for every 5 records
    ![session_batch](http://streamingbook.net/static/images/figures/stsy_0104.png)
  
1. Sessions split across batches
2. No support for event time 

---

### Process Time VS Event Time

![ProcessTimeEventTime](/Users/yoga/Desktop/30.jpg)

**Out of Order, Latency For Unbounded**

---
Now, you have an unbounded data
![unboundedData](http://streamingbook.net/static/images/figures/stsy_0105.png)

Think about your computation:
1. What result are calculated 
2. In which dimensions for calculation

---

1. What result are calculated : 
    sum of click, avg of response time
2. In which dimensions for calculation: 
    sum of click for all the time -> your computation never ends for unbounded data
    sum of click for every 2 mins in process time
    sum of click for every 2 mins in event time
    sum of click for every active session

---
### Window - Processing time

![windowbyprocess](http://streamingbook.net/static/images/figures/stsy_0109.png)

> Pros
- Simple
- Static Window lifetime 

> Cons
- Process time

---
### Window - Event time

![windowsbyeventime](http://streamingbook.net/static/images/figures/stsy_0110.png)


---
### Window - Event time

Window by session based on event time
![windowsbysession](http://streamingbook.net/static/images/figures/stsy_0111.png)

---

### Window - Event time
> Pro
- Powerful semantics

> Cons
- Extended Window Lifetime : Data lentency
- Correctness: Data lentency

---
### Window Type
![windowtype](http://streamingbook.net/static/images/figures/stsy_0108.png)

Fixed: FixedWindows.of(2, MINUTES)
Sliding: window($"time", "2 minutes", "1 minutes")
Session: Sessions.withGapDuration(1, MINUTE)

---
### What: Transformation
Given Input
![input](/Users/yoga/Desktop/31.jpg)

----
### What: Transformation
```
PCollection<KV<String, Integer>> output = input
.apply(Sum.integersPerKey());
```

[AllWindow](http://streamingbook.net/static/images/figures/stsy_0203.mp4)


> Result Latency
> Acurate Correctness

---
### Where: Window
```
PCollection<KV<String, Integer>> output = input
.apply(Window.into(FixedWindows.of(TWO_MINUTES)))
.apply(Sum.integersPerKey());
```

[FixedWindows](http://streamingbook.net/static/images/figures/stsy_0205.mp4)

> Result Latency
> Acurate Correctness

---
### When: Trigger
> Get result more faster?
> Maybe we can calculate for result every 2 minutes

```
PCollection<KV<String, Integer>> output = input
.apply(Window.into(FixedWindows.of(TWO_MINUTES)
             .triggering(Repeatedly(AglignedDelay(TWO_MINUTES)))
      ))
.apply(Sum.integersPerKey());
```
[AglignedDelay](http://streamingbook.net/static/images/figures/stsy_0207.mp4)

> Bursty workload

---

> Not so Agligned
 ```
PCollection<KV<String, Integer>> output = input
.apply(Window.into(FixedWindows.of(TWO_MINUTES)
             .triggering(Repeatedly(UnAglignedDelay(TWO_MINUTES)))
      ))
.apply(Sum.integersPerKey());
```

[UnAglignedDelay](http://streamingbook.net/static/images/figures/stsy_0208.mp4)

---
### Current Problems 

> Trigger are working repeatly, then when could we stop trriger
> Q1: When is the end of the calculation for each window

> Trigger allow us to compute on one window for several times
> Q2: How to aggregate between the temp trigger results

---

### When: Watermark
1. Defines your expected valid data
2. Watermarks is a function, F(P) -> E
3. When to materialize your result

---
### When: Watermark
```
PCollection<KV<String, Integer>> output = input
.apply(Window.into(FixedWindows.of(TWO_MINUTES)
             .triggering(AfterWatermark())
      ))
.apply(Sum.integersPerKey());
```

[watermark1](http://streamingbook.net/static/images/figures/stsy_0210.mp4)

---
### When: Trigger
**Repeated update Trigger**
> periodically generate updated panes for a window as its contents evovle

> balancing latency and cost

**Completness Trigger**
> materialize a pane for a window only after the input for that window is believed to complete to some threshold
> batch: completeness of the entire input
> streaming: completness scoped to the context of a single window 

---
### When: Watermark

Back to the watermark
> Completness Trigger

 **Too slow**
 > 9 holds back for all the subsequenct windows

 **Too fast**
 > Advanced past the window before all the input comes

---
```
PCollection<KV<String, Integer>> output = input
.apply(Window.into(FixedWindows.of(TWO_MINUTES)
             .triggering(
                 AfterWatermark()
                 .withEarylyFirings(AlignedDelay(ONE_MIN))
                 .withLaterFiring(ONE_MIN)
                 )
      ))
.apply(Sum.integersPerKey());
```
[watermark2](http://streamingbook.net/static/images/figures/stsy_0211.mp4)

> Persist state for each window lingers around for the entire life
---

```
PCollection<KV<String, Integer>> output = input
.apply(Window.into(FixedWindows.of(TWO_MINUTES)
             .triggering(
                 AfterWatermark()
                 .withEarylyFirings(AlignedDelay(ONE_MIN))
                 .withLaterFiring(ONE_MIN)
                 )
            .withAllowedLateness(ONE_MIN)
      ))
.apply(Sum.integersPerKey());
```
[watermark3](http://streamingbook.net/static/images/figures/stsy_0212.mp4)

---
### How: Accumulation
> Trigger allow us to compute on one window for several times
> Q2: How to aggregate between the temp trigger results

**Accumulation**
> Discarding
  Every time a pane is materialized, any stored state is discarded

> Accumulating
  Every time a pane is materialized, any stored state is retained, and further inputs are accumulated into the existing state

> Accumulating and retracting
  Besides accumulating, produce independent retractions for the previous pane

--- 

**Discarding**
[discard](http://streamingbook.net/static/images/figures/stsy_0213.mp4 )

**Accumulating and retracting**
[Accumulating and retracting](http://streamingbook.net/static/images/figures/stsy_0214.mp4)

---
### Window Implemention

• Set<Window> AssignWindows(T datum)
> which assigns the
element to zero or more windows. This is essentially
the Bucket Operator from Li [22].

• Set<Window> MergeWindows(Set<Window> windows)
>which merges windows at grouping time. This allows datadriven windows to be constructed over time as data
arrive and are grouped together.

---

![assingWindow](/Users/yoga/Desktop/21.jpg)

---
![mergeWindow](/Users/yoga/Desktop/22.jpg)

---

### Summary

 - What results are being computed = transformation
 - Where in event time they are being computed = window
 - When in processing time they are materialized = trigger + watermark
 - How earlier results relate to later refinements = accumulation





























