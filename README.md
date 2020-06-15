# rhmi-utils

# Getting started

To get started using any of the provided analysis scripts and/or , simply clone the repo to your local machine
```
$ git clone https://github.com/integr8ly/rhmi-utils.git
Cloning into 'rhmi-utils'...
remote: Enumerating objects: 101, done.
remote: Counting objects: 100% (101/101), done.
remote: Compressing objects: 100% (64/64), done.
remote: Total 101 (delta 28), reused 81 (delta 22), pack-reused 0
Receiving objects: 100% (101/101), 26.23 KiB | 26.23 MiB/s, done.
Resolving deltas: 100% (28/28), done.
```

Loading the i8-helper functions is as simple as sourcing ./bin/i8-helpers.sh
```
source </path/to>/rhmi-utils/bin/i8-helpers.sh
```
Its recommended to add this to your .bashrc so that the i8-* functions are always available in new terminals.

## Getting started - analyzing resource data

The analysis scripts are intended to be run against a resource snapshot file created by the get-resources.sh script (see below).  Once you have a resource snapshot file to use, you can use the provided scripts to extract specific pieces of data like so:

```
$ zcat ~/work/api.resources.xyz.json.gz | jq -f scripts/<scipt_name>.jq
```

## Creating a resource snapshot file from an OCP cluster

The get-resources script is designed to be runnable on any machine where oc is installed and logged in as a user with sufficient rights.

```
# Run locally from cloned repo
$ ~/repos/rhmi-utils/support/get-resources.sh <folder/to/save/result>
Data for api.xyz.openshift.com has been extracted to resources.api.xyz.openshift.com.20191210_193053Z.json.gz

# Run from a master node logged in as system:admin using the latest version without git, scp, etc.
$ curl https://raw.githubusercontent.com/integr8ly/rhmi-utils/master/support/get-resources.sh <folder/to/save/result> | bash
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100  2989  100  2989    0     0   9479      0 --:--:-- --:--:-- --:--:--  9458
Data for internal.api.xyz.openshift.com has been extracted to resources.internal.api.xyz.openshift.com.20191210_220140Z.json.gz
```
> `<folder/to/save/result>` is optional, if not provided script will save results in the dynamically created folder 

Saving snapshots before and after making a change, performing an upgrade, etc., especially on production RHMI clusters, can be useful when troubleshooting issues, verifying state, and more.  Comparing output files from different clusters and/or different points in time can be useful.  Comparing two uncompressed output files as-is will typically show too many differences to be meaningful without reducing the data into something more targetted using one of the provided jq script files under scripts/ or creating your own.

### Extracting/Reducing data from a get-resources snapshot file
The most commonly used script is resources_by_namespace.jq which consolidates resource requests/limits from pod specs, storage usage from pvcs and actual cpu/mem usage from pod metrics into totals per namespace.

Using a script is as easy as
```
$ zcat </path/to/get-resources/snapshot/file>.json.gz | jq -f scripts/<scipt_name>.jq
[
  {
...
    "ns": "openshift-codeready",
    "cpu_real": 0.006,
    "mem_real": 379887616,
    "cpu_req": null,
    "mem_req": 1073741824,
    "cpu_lim": null,
    "mem_lim": 2147483648,
    "storage": 1073741824
  },
...
  {
    "ns": "openshift-enmasse",
    "cpu_real": 1.8840000000000001,
    "mem_real": 22897795072,
    "cpu_req": null,
    "mem_req": 72061654016,
    "cpu_lim": null,
    "mem_lim": 72330089472,
    "storage": 28991029248
...
  }
]
```

#### Extracting RHMI cluster resource data and container resource usage
**Note:** Ensure you already have a resource snapshot file

1. Run `zcat </path/to/get-resources/snapshot/file>.json.gz | jq -f ./scripts/rhmi_resources_by_container_pretty_csv.jq -r > containerresources.csv`
2. Run `zcat </path/to/get-resources/snapshot/file>.json.gz | jq -f ./scripts/resources_by_namespace_csv.jq -r > namespaceresources.csv`
3. Open https://docs.google.com/spreadsheets/d/1U_Xigy6ffsgv6ifgDNsJPIuv8NS_kEkb6muc6dZWd-0 or another Google Sheet
4. Import the above csv files into individual tabs
5. *Manual Step:* Namespace sheet: Copy the Cluster totals and RHMI totals rows from the above spreadsheet
    * **Note:** Make sure the RHMI totals cells formula only target RHMI namespaces rows in the sheet.
6. *Manual Step:* Container sheet: Merge storage cells beside each other which have the same workload name and the same storage value
7. Colour code the rows using `Format > Alternating Colours` in Google Sheets


### Creating custom scripts
Its highly recommended to use one of the existing core scripts as a starting point and adapting it for your needs instead of starting from scratch.  While jq is very powerful, its easy to make a mistake and end up with a cartision product between two sets of data when you think you're getting a one-to-one or one-to-many (especially when you're working with such a large amount of input with varying schemas).

**PRO TIP:** If you find yourself tempted to pipe your output thru a unique filter to get rid of duplicate rows that you didn't expect, theres a good chance that you're dealing with an accidental cartision product.

The resources_by_namespace.jq script is a great starting point to use as it demonstrates several techniques:
- using common functions from the i8-helpers module for jq (/lib/jq/i8-helpers.jq)
- breaking up logic into functions
- joining pieces of data from multiple query results
- reshaping data with different schemas
- using normalizeResources/mem_to_bytes from the i8-helpers module to convert memory values from base 2 and 10 units into bytes so that they can be aggregated
The totals from resources_by_namespace are intentionally left raw/unformatted so that the output can be piped into another jq script or other external tools to do additional calculations.

The resources_by_namespace_pretty_csv.jq script includes the same base logic from resources_by_namespace.js; however, its focus is to demonstrate how to turn the raw numbers into human-friendly form using prettyBytes from the i8-helpers module.  When using this script, you'll likely want to include -r (--raw-output) to avoid the double escaping/quotes.
```
$ zcat ~/repos/rhmi-utils/samples/xyz.json.gz | jq -f scripts/resources_by_namespace_pretty_csv.jq -r
"ns","cpu_real","mem_real","cpu_req","mem_req","cpu_lim","mem_lim"
"console-config",0,"14.17 M",,,,
"default",0.79,"1.03 G",1.9,"5.64 G",2,"3.22 G"
"fuse-f0cf75e7-c014-11e9-976b-0a580a820006",0.02,"745.36 M",0.45,"1.73 G",0.75,"3.19 G"
"kube-service-catalog",0.02,"504.57 M",,,,
"kube-system",1.64,"10.13 G",,,,
"openshift-3scale",0.03,"3.72 G",3.35,"5.96 G",12.75,"80.17 G"
"openshift-ansible-service-broker",0,"26.59 M",,,,
"openshift-apicurito",0,"139.73 M",0.4,"134.22 M",2,"536.87 M"
"openshift-codeready",0.01,"379.89 M",,"1.07 G",,"2.15 G"
"openshift-config",0.04,"219.87 M",0.2,"209.72 M",,
"openshift-console",0,"27.34 M",0.3,"314.57 M",0.3,"314.57 M"
"openshift-enmasse",1.88,"22.9 G",,"72.06 G",,"72.33 G"
"openshift-fuse",0.02,"804.86 M",0.45,"1.73 G",0.75,"3.19 G"
"openshift-infra",0.67,"7.7 G",1.33,"20.13 G",,"20.13 G"
"openshift-integreatly-backups",,,,,,
"openshift-launcher",0.04,"1.15 G",0.03,"1.9 G",2.05,"3.27 G"
"openshift-logging",1.86,"69.54 G",2.8,"112.74 G",,"112.74 G"
"openshift-managed-service-broker",0,"19.12 M",,,,
"openshift-metrics-server",0,"70.82 M",,,,
"openshift-middleware-monitoring",0.22,"1.33 G",0.23,"807.4 M",0.33,"492.83 M"
"openshift-monitoring",0.92,"9.17 G",0.57,"1.26 G",0.82,"1.05 G"
"openshift-node",0.04,"203.65 M",,,,
"openshift-psad",0,"303.68 M",,,,
"openshift-sdn",0.16,"1.93 G",2.6,"6.82 G",2.6,"5.45 G"
"openshift-sso",0.03,"578.76 M",,"1.07 G",,"1.07 G"
"openshift-template-service-broker",0.01,"176.31 M",,,,
"openshift-web-console",0.04,"64.18 M",0.3,"314.57 M",,
"openshift-webapp",0,"87.61 M",,,,
"ops-health-monitoring",,,,,,
```

Another way to get machine readable version similar to the output above by piping the output of resources_by_namespace.jq into a custom jq query from the command line is:
```
$ zcat ~/repos/rhmi-utils/samples/xyz.json.gz | jq -f scripts/resources_by_namespace.jq | jq '(.[0] | to_entries | map(.key)), (.[] | [.[]]) | @csv' -r
"ns","cpu_real","mem_real","cpu_req","mem_req","cpu_lim","mem_lim","storage"
"console-config",0.001,14172160,,,,,
"default",0.793,1027137536,1.9000000000000006,5637144576,2,3221225472,
"fuse-f0cf75e7-c014-11e9-976b-0a580a820006",0.020000000000000004,745357312,0.45,1729101824,0.75,3193962496,4294967296
"kube-service-catalog",0.016,504573952,,,,,
"kube-system",1.6400000000000003,10125238272,,,,,
"openshift-3scale",0.033,3715887104,3.349999999999999,5958886656,12.75,80173437952,3221225472
"openshift-ansible-service-broker",0,26587136,,,,,
"openshift-apicurito",0,139730944,0.4,134217728,2,536870912,
"openshift-codeready",0.006,379887616,,1073741824,,2147483648,1073741824
"openshift-config",0.044,219873280,0.20000000000000004,209715200,,,
"openshift-console",0.003,27336704,0.30000000000000004,314572800,0.30000000000000004,314572800,
"openshift-enmasse",1.8840000000000001,22897795072,,72061654016,,72330089472,28991029248
"openshift-fuse",0.017,804859904,0.45,1729101824,0.75,3193962496,4294967296
"openshift-infra",0.669,7697088512,1.3250000000000002,20132659200,,20132659200,322122547200
"openshift-integreatly-backups",,,,,,,
"openshift-launcher",0.038,1148170240,0.03,1904533952,2.05,3271959552,1073741824
"openshift-logging",1.8559999999999994,69535952896,2.800000000000001,112742891520,,112742891520,1610612736000
"openshift-managed-service-broker",0,19120128,,,,,
"openshift-metrics-server",0.003,70819840,,,,,
"openshift-middleware-monitoring",0.223,1328070656,0.225,807403520,0.325,492830720,
"openshift-monitoring",0.915,9172963328,0.5700000000000002,1258291200,0.8200000000000004,1048576000,
"openshift-node",0.036000000000000004,203649024,,,,,
"openshift-psad",0.001,303677440,,,,,
"openshift-sdn",0.15500000000000005,1934340096,2.600000000000001,6815744000,2.6,5452595200,
"openshift-sso",0.033,578756608,,1073741824,,1073741824,1073741824
"openshift-template-service-broker",0.006,176312320,,,,,
"openshift-web-console",0.043,64180224,0.30000000000000004,314572800,,,
"openshift-webapp",0.002,87613440,,,,,
"ops-health-monitoring",,,,,,,
```

## Using `ocm` for installation of RHMI

The `ocm` tool has moved to `delorean` project and the steps needed to spin up an OSD cluster using `ocm` can be found [here](https://github.com/integr8ly/delorean/tree/master/docs/ocm).