# All Projects

Code
- switched scons builder to new version with python3 support
- C++11 transition: getting rid of auto_ptr
- C++11 transition: default C++ standard has been changed to C++11
- C++11 transition: replacement of auto_ptr with unique_ptr for the generated code
- C++11 transition: default standard has been changed to C++11
- updated log4cplus from 1.1.1 to 2.1.1
- removed py27 target for unit tests
- fixed various python3 issues - (str/bytes, imports/dependecies, ...)
- changed versioning from 0.1dev to 0.1.dev0
- added support for kernel 5.15
- added support for IPv6 metadata

Deployment
- switched default executable to python3.6 for all python-based services and tools  
- switched default driver from thrift to CQL for python-based services
- added support for Ubuntu 22.04
- added support for Rocky 9.0, 9.1, 9.2
- added support for new Openstack versions up to 2023.2 with patched kolla-ansible
- added ability to use ansible-deployer with vanilla kolla-ansible

Other
- added automatic docs generating with doxygen
- removed vCenter support
- removed mesos support

# Tf-analytics

- remove topology and snmp-collector UT - nothing useful there [`1269ed9`](http://github.com/opensdn-io/tf-analytics/commit/1269ed9d46c7c2633122d80dd7e48a2ef9c79f90)

# Tf-ansible-deployer

- added support for newer versions of ansible executable
- set python3 as a default executable [`a4e5302`](http://github.com/opensdn-io/tf-ansible-deployer/commit/a4e53021bd3d3b255b9ba5440a4b11e45a963af0)
- improved ansible-deployer for k8s 1.24 [`f22f943`](http://github.com/opensdn-io/tf-ansible-deployer/commit/f22f94380e9abe644f73080582d1b3577443f442)
- increased version for docker-compose config [`01bcbb5`](http://github.com/opensdn-io/tf-ansible-deployer/commit/01bcbb5f3fa37b09f7c87866641adc59bc174f76)
- updated docker-compose to newer version [`8a52b02`](http://github.com/opensdn-io/tf-ansible-deployer/commit/8a52b02f0c85b345c7c4f7473d9cbd6cebcf4dae)

# Tf-container-builder

- add waiting for cassandra is ready to connect for services [`3204561`](http://github.com/opensdn-io/tf-container-builder/commit/3204561d6578060f5d9609b6c003b7dbaf409d4e)
- Allow to customize MTU in kubernetes CNI [`18aebf3`](http://github.com/opensdn-io/tf-container-builder/commit/18aebf3e0c450254e9ed3426c3e13d4e27b09692)
- change keystone admin port to public port [`de3aa90`](http://github.com/opensdn-io/tf-container-builder/commit/de3aa90be74b8e8d0a707c0e0cf83a06c1f5becb)

# Tf-controller

- Change cassandra workers number [`ceaa3c8`](http://github.com/opensdn-io/tf-controller/commit/ceaa3c865833ae6b8fe417b3581a8daca4c15f59)
- Add zookeeper lock on schema change [`0e753de`](http://github.com/opensdn-io/tf-controller/commit/0e753de4c9ca4c538d5b4f6eed3dd6b04ff83358)
- GetSubnetAddress() function is changed to work with both IPv4 and IPv6 prefixes [`cd0ccef`](http://github.com/opensdn-io/tf-controller/commit/cd0ccef93b02da5c54a5927272a94c16ac113c16)
- A vDNS service performance improvement: the single update of bind9 named configuration after the startup of vDNS service was introduced [`e0ebe78`](http://github.com/opensdn-io/tf-controller/commit/e0ebe783f710cb52bb01a4ebad984cf930de90ec)
- Rework process of waiting keyspaces [`e67671e`](http://github.com/opensdn-io/tf-controller/commit/e67671e4fef6dc2a01143cde91fa9143c77fa44c)
- Fix race condition between Statemachine callback and Session delete. [`6abe526`](http://github.com/opensdn-io/tf-controller/commit/6abe526e9c0b4395d00d9a4a5408b929cb37c3dc)
- Changes added to execute UpdateFlowhandle code change only when reverse [`08e7a92`](http://github.com/opensdn-io/tf-controller/commit/08e7a9294a0207b70f93773d6e6e2a7209280ebc)
- Do not maintain the metadata ip in metadata_ip_map_ of VMI for service based (BFD)  health check instance [`e9390fe`](http://github.com/opensdn-io/tf-controller/commit/e9390febbae7d8c27d03b480e53adfccdf6a2b27)
- Fix for Segmentation fault due to invalid static_cast of NH key pointer, TFB-1849, https://jira.tungsten.io/browse/TFB-1849 [`8bb2d81`](http://github.com/opensdn-io/tf-controller/commit/8bb2d81ffcab61d7ba4d4bc3b0cb25a5c4e150be)
- Always store subnet tags to the DB [`82b54fd`](http://github.com/opensdn-io/tf-controller/commit/82b54fd3141def534ee3f1f61cff385747ba149a)
- Pass bridge vrf as argument to routing vrf walker [`482d30c`](http://github.com/opensdn-io/tf-controller/commit/482d30c65ec4755d5a04a6704656fac1cda101a4)
- Add synchronization for mac_ip_learning_map [`a2f1fe8`](http://github.com/opensdn-io/tf-controller/commit/a2f1fe872ce0acb0bddf3f3fe2e9a4c4ca9a2032)
- Fix null value for ICMP protocol via neutron plugin. [`5c82742`](http://github.com/opensdn-io/tf-controller/commit/5c82742dd0caa9ef48ab7364f96f05e451fd0a9a)
- Do not allocate metadata index for service based health check instance. [`574eaed`](http://github.com/opensdn-io/tf-controller/commit/574eaedb8294cf9d39aa5430f091e114ea955e4d)
- Disable Pool used for communication with CQL driver [`8b3f739`](http://github.com/opensdn-io/tf-controller/commit/8b3f739151885bc12a0a66b27534a9a403c7d4f5)
- The fix for the bug with the absence of internal tunnel routes in an L2 table [`86b0230`](http://github.com/opensdn-io/tf-controller/commit/86b0230de3db0daafe4667b660c3fd443a1ddbc2)
- Solves a problem with active-standby AAP routes in the VxLAN routing VRF [`4fac41b`](http://github.com/opensdn-io/tf-controller/commit/4fac41bd3497e31daccd601637ec508d08718e22)
- Added tests for flowing IPv6 routes to vxlan [`8e5adf0`](http://github.com/opensdn-io/tf-controller/commit/8e5adf02ec2073d919958c64fc2e770d047c8622)
- Added tests for flowing IPv4 routes to vxlan [`03cc8b5`](http://github.com/opensdn-io/tf-controller/commit/03cc8b597def02ee149d8b14803f403efac02b61)
- Metadata6 + NAT66: metadata6 service now works via NAT66 ensuring security for cases when there are several machines with equal LL IPv6 addresses [`f6c2579`](http://github.com/opensdn-io/tf-controller/commit/f6c25798133709db1d162d84ebdad2b23fa2a276)
- Metadata6 with vhost fabric VRF routes to the IPv6 LL address of vhost0 interface [`f572cc7`](http://github.com/opensdn-io/tf-controller/commit/f572cc71dbdf46719b49789c646cd3228999969d)
- Updates for new VxLAN routing manager: subnet interface routes 4 BGPaaS, IRT and bug fixes [`7e9e044`](http://github.com/opensdn-io/tf-controller/commit/7e9e0445bf313a4892faa8714480d20b9aabf3d2)
- AgentRoute descendants refactoring: unification of the route prefix access functions [`340d898`](http://github.com/opensdn-io/tf-controller/commit/340d89879400b1a1585196074e250e3064e7c020)
- a vDNS improvement: a bug associated with requests to partial names (e.g., yandex.) has been fixed, support for resolution of IPv6 FIP addresses [`eeba013`](http://github.com/opensdn-io/tf-controller/commit/eeba0139d8b13802f8efc6512ddd2c54c4d25841)
- NAT66 for OpenSDN: NAT66 flows for vRouter Agent, IPv6 support for Floating IP pool, NAT44/NAT66+VxLAN+VRF_T [`34c6468`](http://github.com/opensdn-io/tf-controller/commit/34c646845eb85d665a1563ea78376edc3a411d8e)
- Fix for a bug in WithdrawEvpnRouteFromRoutingVrf and WalkRoutingVrf: disconnection of a bridge VRF instance from a LR deletes all routes in the routing VRF instance. But actually this should delete routes only originating from this VRF instance [`15f6a33`](http://github.com/opensdn-io/tf-controller/commit/15f6a3372918c4e7901f2b7d13b782af5fde3819)
- The problem of memory cleaning in Metadata6 unit test has been fixed [`c81277c`](http://github.com/opensdn-io/tf-controller/commit/c81277c165808e31bdbc44ba041ba80c2a0570f1)
- Solves a problem with HealthCheck when it turns off watched routes after rebooting Agent [`ace26e6`](http://github.com/opensdn-io/tf-controller/commit/ace26e672bbe1c6195ed0fec4d06aadcbe782562)
- Neighbours (ip -6 n a) and routes (ip -6 r a) for VM interface routes (fe80::n) in the compute host OS for Metadata6 service [`feee59b`](http://github.com/opensdn-io/tf-controller/commit/feee59b6e7ac56e101ba563243b4c3c26a0acf46)
- Code styling rules were moved into README.md and updated [`337311d`](http://github.com/opensdn-io/tf-controller/commit/337311df3719e85eefc13f210fe04565171d0677)
- nodemgr: remove double decode() for containerd runtime [`6af4e8b`](http://github.com/opensdn-io/tf-controller/commit/6af4e8bbe023910fc4579be36dc7feb87b1ede23)

# Tf-neutron-plugin

- implements the _get_used_quota function to counting used resources [`1633c05`](http://github.com/opensdn-io/tf-neutron-plugin/commit/1633c05e30313ae08f6ff639f2fc96e3ddb9d7f3)
- Fix get quota issues. [`612335f`](http://github.com/opensdn-io/tf-neutron-plugin/commit/612335f7aa268154e473f3fabfe2d611c6e9a4c8)
- Add classmethod decorator for get_project_quotas method [`c9bdf3a`](http://github.com/opensdn-io/tf-neutron-plugin/commit/c9bdf3afba72868dc9b9ba527a65493cc9953373)

# Tf-packages

- Remove rhel versions &lt;=6, fedora,  from .spec files, fix %endif with no %if, fix net-tools requirement [`5cfcab8`](http://github.com/opensdn-io/tf-packages/commit/5cfcab89819f3594dea99ef50ba15f2a1ff6616e)
- remove explicit pip2 and pip3 requirements for build [`38437f0`](http://github.com/opensdn-io/tf-packages/commit/38437f0c98cb70e56ba38c181b1baedca2cdd394)
- remove pycassa and thrift [`4b2f97f`](http://github.com/opensdn-io/tf-packages/commit/4b2f97f81019cd185284ea078435317ee3153077)
- add Cython package install for cassandra-dirver [`8699093`](http://github.com/opensdn-io/tf-packages/commit/86990932f4385b9c3e0aa573c84af986f37e3f93)
- don't install sphinx for python2 [`df6d314`](http://github.com/opensdn-io/tf-packages/commit/df6d3144b6f9a7b622c4dc1b01510e8104570878)

# Tf-third-party

- update code to be compatible with python3.8 and upper [`bdea237`](http://github.com/opensdn-io/tf-third-party/commit/bdea2374da2f830c7e81a313309de5a078a9edfa)

# Tf-vnc

- remove windows stuff [`4f65f90`](http://github.com/opensdn-io/tf-vnc/commit/4f65f90ab79588e3bc8d184bb193097ea6194d04)
- Remove vCenter projects [`1416f4a`](http://github.com/opensdn-io/tf-vnc/commit/1416f4a622c5a034d66572115f10a2754b4eb832)
- remove source for fat-deployer container [`9f88d26`](http://github.com/opensdn-io/tf-vnc/commit/9f88d268c60c6485f946dcf9a4ffa8adf738247f)
- Remove deployers-containers and openshift containers [`4cc0e99`](http://github.com/opensdn-io/tf-vnc/commit/4cc0e990fb6a075e076d6d4ad01bdd38ed5e2aaa)
- remove helm-deployer from projects [`e93978f`](http://github.com/opensdn-io/tf-vnc/commit/e93978fdd4efb496db76b1ff475eb1276f5e1770)

# Tf-vrouter

- NAT66 for vRouter [`ef617f8`](http://github.com/opensdn-io/tf-vrouter/commit/ef617f8718c0d0c71b473d0a34489a76a5f46d6e)
- fix changes on netif_napi_add & nf_hookfn in rocky9.2 [`94e6823`](http://github.com/opensdn-io/tf-vrouter/commit/94e68230c8bf482e3d951b002c5ea19aca1cb573)

# Tf-web-controller

- Enable 4byte ASN number for BGP. [`f237891`](http://github.com/opensdn-io/tf-web-controller/commit/f237891ba3873548fb24d313a5b577227fb2998c)

# Tf-web-core
- Enables input of IPv6 addresses for the metadata link local service [`b204bbb`](http://github.com/opensdn-io/tf-web-core/commit/b204bbb498a0c51e0b1568e70e6b5cd98b096a33)
