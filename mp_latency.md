---
title: "Two Routes Diverged in the Internet, And Happily I Could Travel Both"
abstract: "For many modern applications with extreme latency sensitivity, throughput is no longer the primary bottleneck. Instead, poor tail latency and sporadic packet loss are the limiting factors. Network protocols such as BGP and TCP were designed with different goals in mind, and most contemporary solutions act reactively, lacking the ability to respond to network condition changes quickly enough to support highly latency-sensitive applications. We take a different approach, by proactively sending redundant traffic down multiple paths, enabling improvements in tail latency and loss resilience at sub-RTT timescales. We evaluate our approach using the PEERING testbed across three continents demonstrating substantial potential to mask sporadic packet loss, masking more than 50% of loss for over 37% of targets and achieving a 0% loss rate for 41% of targets, an 8% improvement over prior approaches. For latency, we find that there is an opportunity to reduce transient latency degradation for 92% of targets. These findings suggest that exposing and proactively using multiple paths can improve reliability for modern latency-sensitive applications, and introduce a new set of research directions in multipath interdomain routing."


author: 
- name: "Paper #649, 6 pages body, 8 pages total"


indent: true
documentclass: acmart
biblio-style: ACM-Reference-Format.bst
classoption:
- sigconf
- nonacm
- screen
- letterpaper
- 10pt
Biblio-style: ACM-Reference-Format.bst
header-includes:
- \pagestyle{plain}
---
\setlength{\footskip}{40pt}
\pagenumbering{arabic}


\eat{github: https://github.com/carsongarland/multipath}


\eat{todo:
* Revise section 2.1 to argue for loss correlation directly
* Rework comparable path section
* Add figure captions
* Tighten latency discussion
* Finish loss discussion
* Review methodology
}

# Introduction
\label{sec:introduction}

The Internet has grown from providing static content to dynamic content and now highly interactive and critical use cases. Enterprise services have tight reliability requirements \cite{painter,saving-private-wan}, and, for applications such as cloud gaming, interactive AR/VR, and remote robotics, high tail latency \cite{augur} or 3 milliseconds of jitter \cite{vr-jitter-test} can lead to degraded user experience. 


Since the Internet only provides best effort service, congestion and loss on wide-area paths are common \cite{akella-congestion, dhamdhere2018inferring}, reaching as high as 8\% loss on some wide-area paths carrying enterprise traffic \cite{silverpeak-loss-info}. So, while minimum and even common case latencies are quite good \cite{whyhigh, calder2015analyzing, latency-shears, tom-anycast, brandon-facebook-imc}, \emph{tail} latency continues to limit the Internet's ability to serve demanding applications. While there have long been efforts to provide multiple classes of service \cite{diffserv-rfc, intserv-rfc, l4s-rfc}, it is unclear if they will see widespread adoption. 


With the Internet core providing only best effort service, practitioners are forced to deploy approaches at the edge that try to mitigate the impact of degradation in the core, but no existing solutions suffice for truly demanding applications. Approaches from congestion control to intelligent route control measure performance and, based on these measurements, adapt sending rate or which path to use \cite{calder2015analyzing, painter, anyopt, espresso, edge-fabric, fastly-egress}. These approaches are inherently \emph{reactive}, requiring at least one round trip delay to detect an issue and adjust, by which time demanding applications already experience degraded service. Proactive approaches have been used in some other contexts, but they do not sufficiently improve performance on the Internet for demanding applications (\cref{sec:motivation-limitations-existing}). \eat{ For applications that cannot tolerate this impairment, \emph{proactive} approaches must be used. Some approaches reduce latency by proactively sending redundant traffic along a single path to mask loss \cite{tcp-gentle-aggression, brighten-conext2013}, but the redundant traffic must be delayed to decorrelate loss and cannot mask delay and jitter experienced along the path. To avoid this delay, \emph{proactive multipath} approaches are necessary. Overlay networks are one option for multipath routing \cite{sdwan,monet}, but the need for an overlay limits them to certain settings and incurs expenses. Other solutions use multiple paths to aggregate bandwidth over different wireless links \cite{remp, twinstar}. Such solutions likely have a part to play in delivering reliably low-latency services, but they are not a current solution to avoiding wide-area impairments, as cellular links incur too high of a latency to be competitive \cite{urllc-close-reality-distant-goal}. }


We argue that, in the foreseeable future of the Internet, the only path to delivering applications that demand low latency requires masking Internet loss and delay by proactively sending redundant traffic across multiple wide area paths in parallel. Our key insights are that it is common for multiple paths to have similar latency yet low correlation of delay spikes and loss, and so we can reduce tail latency drastically through redundant transmission. Our approach is incrementally deployable, relying only on functionality supported by modern clouds and application-based modifications, essential properties for adoption \cite{panrg}.


We demonstrate the potential of this approach using measurements from three public cloud data centers in different continents to networks near (and hence served by) the data centers (\cref{sec:methodology}). Our experiments use a single path from the cloud to the targets, and multiple paths from the targets back to the cloud, and so our measurements only avoid impairments along half the path. Current cloud technologies support multiple paths in both directions, and so our results reflect a lower bound on the achievable improvement. 


Our measurement results show that our proactive multipath approach is able to mask more than 50\% of loss for over 37\% of targets, achieving a 0% loss rate for 41\% of targets (\cref{sec:loss}). This approach reduces the fraction of targets experiencing latency degradation above the thresholds for highly latency-sensitive applications in more than 10\% of cases by 19\%, and that only 8\% of targets have one single path that consistently provides the lowest latency so it is beneficial to add proactively redundancy across multiple paths (\cref{sec:latency}).


Effective strategies such as CDNs and geo-replication of services, incorporating feedback from the network, and using multiple paths reactively or in the last mile have brought performance-intensive applications to billions of connected users. Despite these efforts, the Internet's best effort delivery and the accompanying latency spikes and loss make delivering \emph{highly} intensive, critical applications difficult. Our approach demonstrates the potential of building reliable, high-performance systems over many inherently unreliable paths, pushing us towards providing the performance that our next-generation Internet use cases need. We conclude the paper with a description of research problems to address to realize this potential.



# Motivation and Related Work
\label{sec:motivation-related-work}
\label{sec:motivation}


User-facing Internet applications require increasingly stringent performance from the network. For example, cloud gaming is highly sensitive to stalls in frame delivery, with Tencent reporting that just a 0.5\% increase in stall rate in their cloud gaming service decreases user retention time by 33\%, and 99.9th percentile tail latency of 200 ms for frame delivery is likely to cause stalls \cite{augur}. Virtual and augmented reality, which are emerging applications that utilize the network for distributed participants and cloud offloading of some tasks, ideally desire application-level latency of 20 ms \cite{simulator-sickness-getmobile17}, and a VR user study with offloaded rendering showed that quality of experience degrades as network latency increases from 20 to 50 ms and degrades further when that latency has real-world variability as opposed to constant latency \cite{gao25xrgo}. Other applications such as enterprise cloud have become increasingly essential, and performance problems can hinder the efficient function of businesses \cite{painter}. 


However, the Internet only offers a single best-effort service as traffic traverses multiple ASes. Problems such as congestion and loss can occur in any one of these ASes \cite{akella-congestion, dhamdhere2018inferring} reaching as high as 8\% loss \cite{silverpeak-loss-info}. These problems are traditionally only detected by endpoints via feedback (\eg TCP reliable delivery mechanisms) after at least a round trip's delay, as shown in \Cref{fig:comparison_other_approaches}a.


Many efforts have tried to replace this single best-effort service with multiple types of service to provide more reliable performance, such as IntServ \cite{intserv-rfc}, DiffServ \cite{diffserv-rfc}, the SCION network \cite{scion_deployment_conext}, and L4S \cite{l4s-rfc}. However, none of these proposals has seen widespread adoption despite decades of effort, due to the difficulties of deployment across domains. Hence, existing approaches that can be adopted at scale tend to lie at the \emph{endpoints} where application developers have more control over what happens to traffic. 



## Limitations of Existing Approaches
\label{sec:motivation-limitations-existing}


\eat{\tbd{We should perhaps mention CDN and cloud buildout as another approach}}


  

\begin{figure}
    \centering
        \includegraphics[width=\columnwidth]{figures/mp-latency-comparison.pdf}
    \caption{Comparison of our approach to other approaches.}
    \label{fig:comparison_other_approaches}
\end{figure}




\textbf{Proactively sending redundant traffic over a single path cannot eliminate latency problems.} Some approaches add redundancy (such as duplicate packets or forward error correction) to sent traffic, masking loss without incurring the delay of reactive retransmission-based loss recovery \cite{virtue-gentle-aggression, brighten-conext2013, vu2021supporting}. However, in the wide area, much of the latency degradation, loss, and jitter is because of congestion, and so packets on the same path at similar times will experience similar conditions. This effect is shown in \Cref{fig:comparison_other_approaches}b where the redundant packet is also lost due to congestion on the single path, despite the possibility of sub-RTT loss-mitigation.


\textbf{Switching between different paths is inherently reactive, moving traffic away from a path only after observing its poor performance.}
Intelligent route control approaches, from an older generation such as network appliances from Internap \cite{internap} to more recent approaches from cloud/content providers such as Edge Fabric \cite{edge-fabric} and PAINTER \cite{painter}, monitor the performance of multiple routing options in parallel and choose the one they anticipate performing the best \cite{akella-multihoming-nsdi-04, internap, edge-fabric, espresso, fastly-egress, painter, entact, cascara}. However, these approaches will not shift traffic until they observe a problem, which requires at least a round trip during which performance is degraded, as shown in \Cref{fig:comparison_other_approaches}c. 


\textbf{Multipath on the wireless last mile may be part of the solution but is too high latency.}
Multipath routing has been used for devices with multiple last-mile connections, most often where one is cellular and the other is WiFi \cite{augur, remp, twinstar, apple-mptcp}. These approaches are used primarily for bandwidth aggregation and likely have a part to play in delivering reliably low-latency services. However, they are not a current solution to avoiding wide-area impairments, as wireless links incur too high of a latency to be competitive \cite{urllc-close-reality-distant-goal}. Although 5G has a proposed Ultra-Reliable Low Latency Communication (URLLC) service, and multi-channel transport approaches exist to take advantage of it \cite{dchannel}, URLLC is not deployed in practice.


\textbf{Current, proprietary solutions proactively send redundant traffic, but these solutions cannot be used across the Internet.} Some solutions send enterprise traffic across overlay networks to improve performance reliability \cite{cisco-sdwan, akamai_sase, cloudflare_argo, livenet, inap, subspace}, including some like Silverpeak that do forward-error-correction across multiple paths using SD-WAN \cite{silverpeak-loss-info}. However, those solutions are (a) proprietary, (b) limited to certain settings, and (c) potentially do not scale. 


By (a) and (b) above, we mean that these products are often closed-sourced to protect intellectual property and are \emph{products} intended for enterprise networks. Hence, these solutions are neither intellectually nor physically available to the Internet as a whole.


By (c) we refer to the fact that replicating every byte of all Internet traffic across every path between two endpoints all the time is likely not scalable. Instead, we have to replicate \emph{important} traffic that ensures latency-intensive applications work well (see \Cref{sec:future-directions} for more discussion). SD-WAN devices do not have visibility into which traffic is important and which is not, so it is unclear how one would use such technology to improve performance for latency-intensive applications.

## Proactive, Redundant, Multipath, Deployable


We argue that the only way to reliably provide low latency and loss across today's Internet is to combine the insights of these approaches to overcome their limitations. Specifically, a solution that provides reliable, low-latency performance must:


1. Proactively send redundant packets to avoid the delay of reactive approaches.
2. Use multiple paths with similar baseline performance, each of which has low enough baseline latency to provide the requisite performance for demanding applications.
3. Use multiple paths in parallel to avoid jitter and instantly mask loss.
4. Be deployable across the entire Internet.


The relative benefit compared to prior approaches is shown in \Cref{fig:comparison_other_approaches}d where we recover from loss in less than an RTT, allowing the latency-sensitive application to continue working.

## This is Achievable on Today's Internet


Proactively sending redundantly across multiple paths can realize meaningful performance gains on today's Internet. To demonstrate this fact, we next show that much of the loss and latency degradation on the public Internet can potentially be avoided using measurements from a large public cloud (\cref{sec:results}) and discuss the open design questions to address to realize these gains (\cref{sec:future-directions}).


Importantly, once questions are addressed to decide what traffic to send along which paths, today's Internet should be able to immediately support the approach. Work from Facebook demonstrated how a content/cloud provider can make performance-informed decisions on how to use multiple paths towards a client \cite{brandon-facebook-imc}, despite BGP being single path and performance-agnostic. Although Facebook found that the performance of the multiple paths was usually so similar that it was not worth maintaining a system to switch between them as performance varied, that same finding is a \emph{benefit} for our goals (\cref{sec:results}), as it provides an opportunity to race content along similarly performing paths to avoid the impact of short-term impairments. 


Work from Microsoft demonstrated how a content/cloud provider can use multiple paths in the opposite direction, back from clients towards the content/cloud provider \cite{painter}. TANGO argued that a similar approach can be used between smaller edge networks \cite{tango}. Although these previous works chose one path at a time, the architectures do not need to be changed to use multiple simultaneously. Multipath QUIC \cite{mpquic-conext} is under discussion at the IETF \cite{mpquic-rfc}, and is already used by a large cloud \cite{alibaba-mpquic}, along with QUIC extensions for unreliable datagrams \cite{quic-unreliable-datagrams-rfc} and forward error correction \cite{quic-fec}, providing building blocks for application-based multipath transport. Combined, existing mechanisms for multipath routing and multipath transport provide the building blocks that make the techniques we argue for immediately deployable. 


\eat{



## related work
* Proposing or measuring multipath traffic direction technologies
   * Interactions between selecting multiple paths and tcp cc
   * Avoid self loading at small time scales
   * On the Performance Benefits of Multihoming Route Control, ToN 2008
      * Inbound route control by using different source addresses
   * Multihoming performance benefits
   * Strategies of choosing different routes in multihoming
   * Congestion
      * Inferring persistent interdomain congestion
      * Bottlenecks in public internet
* Other folks have noted current protocols limit what you can do on the Internet and have done things to combat this
   * Mentions or could give better performance improvements at small time scales
      * Painter, miro, tango
      * Some things turned into commercial systems (basically fancy overlay networks)
         * Avaya, Inc., "Converged Network Analyzer".
         * Cisco Systems, Inc., "Optimized Edge Routing".
         * Akamai_sase, cloudflare_argo,livenet, inap, subspace
   * Steady state performance improvements
      * Anycast ppp, miro
         * Propose modifications to bgp
      * Calder2015analyzing,footprint-microsoft,fastroute,anyopt,jiangchen-cdn-imc,regional-anycast,anycast-playbook,pecan,painter,
         * Expose more routes via lots of advertisements
      * Scion, routescout
         * New architectures
   *    * Ietf / technological pushes to offer more flexibility
      * L4s, masque, panrg
   * Egress traffic engineering
      * espresso, edge-fabric, fastly-egress
* comparison with multi-interface multipath (remp, twinstar)
   * over the last mile
   * how we are different
      * expose more paths of comparable performance
      * protocol/application agnostic (the two approaches are complementary)
      * not tied to interfaces, multiple internet paths
      * REmp (icc16):
         * fully redundant traffic on both wifi and cellular networks, can only get as many paths as nics
         * optimizing for latency
      * Twinstar (mm23): 
         * similar to remp but being smarter about what traffic goes where and error correction
         * optimizing for video metrics (stalls/quality)
* Internet performance from Facebook's edge
* single path redundancy (virtue of gentle aggression, etc)
   * how we are different
      * able to access more than one path
      * get the performance benefits of multiple paths




}

# Methodology
\label{sec:methodology}


To demonstrate the potential of proactive redundancy across multiple paths, we conduct measurements from a large public cloud, Vultr, to thousands of ASes. We configured BGP announcements from Vultr to enable us to steer responses to different paths back to the cloud from each target. 



## Experimental Setting
We conduct measurements using the PEERING testbed \cite{schlinker19peering}, which is now deployed on 32 Vultr sites. Vultr is a large public cloud that allows cloud customers (including PEERING) to advertise their own prefixes using custom BGP configurations \cite{vultr}. By advertising a different prefix to different Vultr providers, we can control which provider the response to a ping takes by sourcing the ping from an address in the prefix we announce to the provider. Hence, the multiple paths in our setup are the different \emph{reverse} paths from the ping target to the testbed. Prior work used a similar methodology to expose multiple paths through the Internet \cite{painter}. Other systems enable multiple forward paths from the cloud \cite{edge-fabric,todd-cloud-latency}, and realizing the best round-trip multi-path options is a good direction for future work (\cref{sec:future-directions}). 


Since each prefix defines a single path per ping target, the limited number of prefixes available to us limited the number of sites from which we could conduct measurements. We chose three regions for our measurements: the United States, the European Union, and Southeast Asia, to cover a large yet diverse set of targets. In each of our three regions, we announce a unique /24 prefix exclusively to each of four Vultr providers, as well as one /24 prefix to all Vultr providers and peers to obtain the BGP paths used by standard Vultr-hosted services, giving all targets up to five paths to each site (four specific providers plus the standard route provided by BGP).



## Target Selection and Probing


We chose targets from the IPv4 hitlist \cite{ant_ip_hitlist}. Using Routeviews prefix to AS mappings \cite{routeviews}, we obtain their originating AS and exclude IP addresses from prefixes originating from multiple ASes. For each site, we choose a set of nearby countries for each region (\cref{tab:regions-countries}). We geolocate the IP addresses with MaxMind to the country level \cite{maxmind} and sample across originating ASes with weights corresponding to their APNIC-estimated Internet user population in the region (with at least one IP from each available AS) \cite{apnic_pop_est}. Prior work found MaxMind to be accurate for end-users to the country level \cite{maxmind}, and other work found APNIC to be a good proxy for user population \cite{loqman-apnic}. We conduct a short preprocessing round of measurements from each site where we ping each IP address in that site's sample 10 times. We then exclude unresponsive targets, targets that have a median RTT greater than 100ms (a reasonable threshold given where we expect targets to be), and targets that have an average loss rate greater than 60\% via any path to that site.  


Unfortunately, excluding the IP addresses through preprocessing disturbs the weight sampling by the estimated AS population. Hence, we randomly downsample the preprocessed IP addresses to get closer to the original population-weighted distribution of IP addresses per AS (keeping at least one IP address from each AS). In the end, our target sets have 24k IP addresses in the US region (6.4k ASes), 16k IP addresses in the EU region (4.4k ASes), and 4k IP addresses in the SEA region (560 ASes). The IP addresses in the final sets span across 11,177 ASes  representing, on average, 75\% of the populations of those regions according to APNIC \cite{apnic_pop_est}. \eat{When considering the APNIC user population estimates \cite{apnic_pop_est}, we find that the covered ASes account for approximately 94.8\% of estimated users in the US region, 73.8\% in the EU region, and 53.9\% in the SEA region.}


We conducted measurement sets with batches of 2,000 targets at a time to limit our probing rate. For each batch of targets, we issue 500 rounds of measurements to every target via every path each round. The rounds have a period of 4.5 seconds and generate about 1 Mbit/s of traffic spread over all 5 paths. We use this concept of rounds to retroactively quantify the impact of having different sets of paths available to a target. When considering the performance to a target by a set of paths, we take the lowest latency ping amongst those paths in each round.

# Results
\label{sec:results}


\eat{


Potential flow:
* Alternate paths can help you get better performance
   1. Steady state latency is good on alternate paths (questionable utility)
   2. You can get around latency spikes by using alternate paths
      * You can get around jitter spikes by using alternate paths
   3. You can get around loss by using alternate paths
* And we can do it without duplicating all the traffic down every single path
   1. Can you, for each destination, easily implement a learning scheme that figures out the best secondary path to send good things down?


}



## Can Multiple Paths Mask Loss?
\label{sec:loss}
Masking loss improves the performance of latency-sensitive applications, as they do not incur the additional delay involved in detecting the loss and resending the lost packet. Overall, we lost 1.3 million pings of our total 218 million pings across all reachable targets, a loss rate of 0.63\%. Across targets, we observe a median loss rate of 0.4\% and 99th percentile of 14\%. 


  

\begin{figure}[h]
       \centering
        \includegraphics[width=\columnwidth]{figures/masked-loss.pdf}
\caption{CDF of loss masking across all targets. Using a second path masks at least some loss for 51\% of targets.} 
    \label{fig:masked-loss}
\end{figure}


For each target, we use the lowest loss path over the entire measurement window as \emph{baseline} and find the additional paths that minimize the loss rate when used in combination to comprise our multipath set. We define a loss as masked on our target's baseline path if there exists a different path in the target's path set that did not suffer from a loss in the same round. \Cref{fig:masked-loss} shows that, with just one additional path on top of the lowest loss path, we are able to mask at least some loss for 51\% of targets and mask greater than 50\% of packet loss for more than 37\% of targets. This result suggests that we are able to identify a pair of paths where loss events are often not correlated across paths. We find that there are steep diminishing returns on additional paths after the second and observe that, with a third path, we only increase the amount of targets that we can mask 50\% of loss for by 0.004\% as shown by the nearly overlapping lines in \Cref{fig:masked-loss}. 


\eat{One aspect of our measurement set-up is that we only use multiple paths from the targets back to the cloud, with all pings sharing the same path from the cloud to a certain target. Even with the multiple paths we expose, there may be substantial overlap between them for a given target. As a result, it is possible that a significant portion of the loss that we observe is happening on a shared portion of the paths and thus may be unable to be masked within our current measurements.}


To ground the improvements from loss masking, we compare the loss rate achieved with proactive multipath to that of both the standard path provided by BGP and a realistic reactive multipath approach (\ie the strategy used in  \Cref{fig:comparison_other_approaches}c and in prior work \cite{painter,miro,internap,edge-fabric}). We define this approach as a \emph{reactive} strategy that always selects the path with the lowest RTT from the most recent measurement and uses it for the next transmission. In our case, since we have complete measurements from all paths, we simulate this approach by selecting the path with the lowest RTT in the previous measurement and evaluating whether that choice would have resulted in a loss in the subsequent measurement round.
  



\begin{figure}[h]
       \centering
        \includegraphics[width=\columnwidth]{figures/loss-log-cdf.pdf}
\caption{CDF of loss rate across all targets. Proactive multipath provides a 9\% increase in targets that experience zero loss while reactive multipath provides little benefit.} 
    \label{fig:loss-log-cdf}
\end{figure}


We show in \Cref{fig:loss-log-cdf} that proactive multipath is able to reduce the loss rate over both the standard BGP paths and the reactive multipath technique. Our approach is able to increase the proportion of targets with no loss from 32\% with the standard BGP path and 33\% on the reactive multipath to 41\% using our proactive multipath. With new and demanding applications such as AR often requiring loss rates under $10^{-3}$  \cite{3gpp-app-reqs}, our approach enables 8.3\% more targets to meet this threshold compared to the BGP path, and 7.5\% of targets when compared to the reactive multipath Additionally, we see that the 99th percentile loss rate decreases from 2.8\% with the BGP path to 2.6\% with the reactive multipath and further to 1.2\% with our proactive multipath approach. We achieve this improvement across the targets even with just a naive selection of a fixed set of the same providers in all three measurement regions. With our measurement setup only providing multipath for one direction of the end-to-end path, these results demonstrate that there is still significant potential for loss rate reductions using multiple paths rather than the reactive multipath provided by most prior work \cite{akella-multihoming-nsdi-04, internap, edge-fabric, espresso, fastly-egress, painter, entact, cascara}. Directions for further improvement (\cref{sec:conclusion}) include smart path selection, smart use of redundancy (\eg forward error correction approaches could be resilient to contemporaneous single packet losses on \emph{all} paths), and bidirectional multipath.

## Can Multiple Paths Smooth Latency?
\label{sec:latency}
Even when packets are successfully delivered, routing changes, congestion, or other transient issues can still negatively affect packets by delaying them. This increase in latency can degrade applications that require stable and timely packet delivery, especially when it exceeds latency thresholds that are critical for application performance. If the event that causes the latency degradation occurs on the independent segments of the multiple paths used, sending redundantly along multiple paths can potentially mitigate this problem. We next assess to what extent we are able to use this idea to mitigate transient latency degradation.



### Reducing Transient Latency Degradation


We assess the ability of our proactive multipath approach to avoid or mitigate latency degradations that exceed critical thresholds compared to a reactive multipath approach.


\eat{We treat each measurement pair as an independent sample, capturing latency degradations that can occur even on otherwise well-performing paths. For every measurement pair, we apply a method similar to how the additional baseline path was derived for loss masking in \Cref{sec:loss} and examine the latency change on the path that yielded the lowest RTT in the first measurement in the pair.}


Our focus is on three latency degradation thresholds---3 ms and 10 ms, which reflect the requirements of latency-sensitive applications \cite{vr-jitter-test, 3gpp-app-reqs}---and 20 ms, which provides intuition on more severe performance drops. We observe latency degradation in at least 10\% of measurement pairs by at least 3 ms for more than 32\% of targets, by at least 10 ms for close to 6\% of targets, and by at least 20 ms for over 2\% of the targets.
  

\begin{figure}[h]
       \centering
        \includegraphics[width=\columnwidth]{figures/latency-degradation.pdf}
\caption{Proactive multipath reduces latency degradation for critical thresholds compared to reactive multipath by up to 33\%.} 
    \label{fig:latency-degradation}
\end{figure}


Issues occurring on independent segments of the available paths will not affect the duplicate packets sent along alternate paths. In such cases, using multiple paths can reduce latency degradation. If we consider not just the previously best path (reactive multipath) but all available paths (proactive multipath) in the second measurement of each pair, we observe frequent RTT improvements and can avoid many latency degradations exceeding the defined thresholds. These effects are illustrated in \Cref{fig:latency-degradation}, where the proactive multipath lines represent the distribution of degradation when selecting the best among all available paths, rather than restricting to the previously best one. With proactiveness, the fraction of targets experiencing degradation above the 3 ms threshold in over 10\% of measurement pairs drops by 19\%, from 32\% to 26\%, while for the 10 ms threshold it drops by 33\%, from 6\% to just over 4\%. For the 20 ms threshold, the reduction is more modest---about a quarter of a percentage point.



### Fully Mitigating Transient Latency Degradation


\Cref{fig:fully-mitigated} demonstrates that, in some cases, proactive multipath redundancy can fully mitigate all of the latency degradation (i.e., instead of threshold-exceeding latency degradation, the RTT will remain unchanged or even lower across the two measurements). We find that our proactive multipath approach fully mitigates at least some latency degradations for over 41\% of targets at the 3 ms threshold, 21\% at the 10 ms threshold, and 14\% at the 20 ms threshold. Some subset of targets also see even more substantial gains: for the 3 ms threshold, around 17\% of targets fully mitigate more than 10\% of their would-have-been latency degradations. Similar, but smaller, effects are also visible at the 10 ms and 20 ms thresholds.


  

\begin{figure}[h]
       \centering
        \includegraphics[width=\columnwidth]{figures/fully-mitigated.pdf}
\caption{CDF of fully mitigated latency degradations across all targets. Fully mitigated at least some latency degradation for more than 41\% of targets.} 
    \label{fig:fully-mitigated}
\end{figure}


The full mitigation of what would have been a threshold-exceeding latency degradation without multipath suggests that at least two of the available paths to a target offer similar latency performance. Since having multiple low-latency paths that are also comparable increases the likelihood of such mitigation benefits, we explore how often this occurs. 


For each target, we identify the lowest-latency path based on median latency and observe whether the median latency of the other paths falls within 5\% of this lowest median. We find that 66\% of our targets have 2 or more paths (\ie at least one more path comparable to the lowest latency one) and 40\% of targets have 3 or more such paths. We do not observe this many targets benefiting from full mitigation which is expected. Achieving high rates of full mitigation requires not only multiple low-latency paths but also ones that do not share the part of the path causing poor performance. Selecting and identifying such independent, high-quality paths is an interesting direction for future work (\cref{sec:future-directions}).


  

\begin{figure}[h]
       \centering
        \includegraphics[width=\columnwidth]{figures/latency-mitigation.pdf}
\caption{CDF of measurement pairs that can be reduced with proactive multipath across all targets.} 
    \label{fig:latency-mitigation}
\end{figure}


Mitigating or fully avoiding latency degradation offered by multipath can help prevent worsening of user experience for the highly latency sensitive applications. Lowering the latency in general can help improve the user experience even further. Intuitively, multipath either maintains or reduces latency by replicating packets across all available paths and relying on the one with the lowest RTT to deliver the result. \Cref{fig:latency-mitigation} shows the proportion of successive measurements in which multipath achieves lower latency compared to following the best path of the previous measurement. We find that there are only 8\% of targets where the best path remains the best path in all measurements, and multipath cannot help decrease the latency. For all the remaining targets, multipath manages to reduce the latency in at least some fraction of the measurements, with improvements in at least 50\% of measurements for more than 20\% of targets.



# Discussion and Future Directions
\label{sec:future-directions}
\label{sec:conclusion}


Our results demonstrate that multipath routing is possible over the Internet and that even having multiple paths in a single direction has the potential to mask loss and latency degradations (\cref{sec:results}). To realize this potential, it will be necessary to design a solution that addresses a number of open challenges, as it is not scalable to send all traffic redundantly along all paths.


One research direction will be to determine the best paths to use. Simply picking the two or three lowest latency paths may not be the best strategy, because the paths may have similarly low latency because they have significant link overlap, which would make redundancy less useful or even counterproductive. Ideally one wants paths with low latency, low jitter, low loss, and low overlap (and hence low degradation correlation), but it is unclear how to balance these metrics when trade-offs are necessary. Even given a balancing strategy, measuring and continuously reassessing these properties at scale (across hundreds of thousands of prefixes on both the forward and reverse paths) may require new measurement techniques. The set of available paths need not be thought of as static, and it may be possible to explore manipulating BGP announcements to minimize path overlap and achieve other desirable properties.


Another research direction involves developing transport and application layers to take advantage of the multipath redundancy. Given the overhead of sending redundant information, it seems clear that whether and how much a message is sent redundantly should depend on how critical and demanding the message is to the application. One can imagine various design points worth exploring, from ones that expect applications to convey exact QoS requirements to ones that simply enable indicating which subset of messages are high priority. 


Finally, it will be worth exploring what redundancy to use, and how it varies with path properties and application message needs. When should one use forward error correction versus replication? What forward error correction configurations make sense, depending on the settings? Can one infer when degradations are more likely to happen and use more redundancy then? For example, the tail packets of bursts are more likely to be lost because of self-congestion \cite{virtue-gentle-aggression}, and loss is more likely the larger the burst size or bytes in flight. 


As long as the Internet provides only best-effort service, addressing these questions is necessary, as the only pathway to delivering applications that demand reliably low latency and loss includes proactively sending redundant information over multiple paths (\cref{sec:motivation}).


\eat{
* We can't just send all the traffic down all the paths, that doesn't scale
* So we need to pick
   * As few extra paths as possible
      * Soln: try a simple learning scheme
   * As little extra traffic as possible
      * Soln: implement in the application using MPQUIC or something and let application developers choose which traffic is important to get there quickly
}


\eat{
* transport layer to take advantage of the multiple paths
   * need multiple prefixes, suitable for server-side MP, potentially enforceable in a different way (future work, maybe some sort of proxy/using multiple edge deployments?)
   * provider/peer limitations, perhaps aps not optimal (pending measurements)
   * application api to choose to maximize for certain metrics
* Replacing full redundancy with smart encoding (extended/improved twinstar) or apply only to specific packets
}




\eat{\textbf{Acknowledgements.} This work used [cloud-names] thru the CloudBank project, which is supported by National Science Foundation grant 1925001.}


\pagebreak


\newpage


\appendix



# Appendix
\label{sec:appendix}



## Ethics
Extensive efforts were made to limit any negative effects of our measurements, including the use of ICMP packets of only 58 bytes, restricting the bandwidth to any one target used to <5 kbps at peak with delays in-between measurements to any one target, and adding a link to a website explaining the experiment and offering a simple opt-out option to the payload of all packets. We received no request to opt-out. Additionally, all measurements performed for this work followed the Acceptable Use Policy requirements of the PEERING testbed \cite{schlinker19peering}. Consequently, to the best of the authors' knowledge, this work does not raise any ethical concerns. 



## Target Preprocessing
\label{sec:target-processing}


\begin{table}[h]
\centering
\begin{tabular}{|l|l|l|}
\hline
\textbf{Region} & \textbf{Country Name} & \textbf{ISO Code} \\
\hline
United States (US) & United States & US \\
\hline
European Union (EU) & Austria & AT \\
 & Belgium & BE \\
 & Bulgaria & BG \\
 & Croatia & HR \\
 & Cyprus & CY \\
 & Czech Republic & CZ \\
 & Denmark & DK \\
 & Estonia & EE \\
 & Finland & FI \\
 & France & FR \\
 & Germany & DE \\
 & Greece & GR \\
 & Hungary & HU \\
 & Ireland & IE \\
 & Italy & IT \\
 & Latvia & LV \\
 & Lithuania & LT \\
 & Luxembourg & LU \\
 & Malta & MT \\
 & Netherlands & NL \\
 & Poland & PL \\
 & Portugal & PT \\
 & Romania & RO \\
 & Slovakia & SK \\
 & Slovenia & SI \\
 & Spain & ES \\
 & Sweden & SE \\
\hline
Southeast Asia (SEA) & Malaysia & MY \\
 & Thailand & TH \\
 & Indonesia & ID \\
 & Vietnam & VN \\
 & Philippines & PH \\
 & Brunei & BN \\
 & Cambodia & KH \\
 & Laos & LA \\
 & Hong Kong & HK \\
 & Taiwan & TW \\
 & Sri Lanka & LK \\
 & Singapore & SG \\
 & Myanmar & MM \\
 & Timor-Leste & TL \\
\hline
\end{tabular}
\caption{Countries included in each region for IP sampling}
\label{tab:regions-countries}
\end{table}






\newpage


\iffalse
Don't remove this iffalse
