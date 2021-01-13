#!/bin/bash

# One off script to add extra labels to all resources in 3scale namespace
THREESCALE_COMPONENT=threescale_component 
THREESCALE_COMPONENT_ELEMENT=threescale_component_element

oc project openshift-3scale

# Adding the threescale_component label
for COMPONENT in apicast backend system zync
do 
    for POD in $(oc get po| grep $COMPONENT | awk '{print $1}')
    do
        echo Label $THREESCALE_COMPONENT=$COMPONENT added to pod $POD 
        oc label pod $POD $THREESCALE_COMPONENT=$COMPONENT 
    done

    for REPLICATIONCONTROLLER in $(oc get replicationController | grep $COMPONENT | awk '{print $1}')
    do  
        echo Label $THREESCALE_COMPONENT=$COMPONENT added to replicationController $REPLICATIONCONTROLLER
        oc label rc $REPLICATIONCONTROLLER $THREESCALE_COMPONENT=$COMPONENT 
    done

    for ENDPOINTS in $(oc get endpoints | grep $COMPONENT | awk '{print $1}')
    do
        echo Label $THREESCALE_COMPONENT=$COMPONENT added to endpoints $ENDPOINTS
        oc label endpoints $ENDPOINTS $THREESCALE_COMPONENT=$COMPONENT
    done
    for PVC in $(oc get PersistentVolumeClaim | grep $COMPONENT | awk '{print $1}')
    do
        echo Label $THREESCALE_COMPONENT=$COMPONENT added to PersistentVolumeClaim $PVC
        oc label PersistentVolumeClaim $PVC $THREESCALE_COMPONENT=$COMPONENT
    done
    for SVC in $(oc get service | grep $COMPONENT | awk '{print $1}')
    do
        echo Label $THREESCALE_COMPONENT=$COMPONENT added to service $SVC
        oc label service $SVC $THREESCALE_COMPONENT=$COMPONENT
    done
    for DC in $(oc get dc | grep $COMPONENT | awk '{print $1}')
    do
        echo Label $THREESCALE_COMPONENT=$COMPONENT added to deploymentConfig $DC
        oc label dc $DC $THREESCALE_COMPONENT=$COMPONENT
    done
    # majority of configmaps are covered by this for loop
    for CONFIGMAP in $(oc get configmap | grep $COMPONENT | awk '{print $1}')
    do
        echo Label $THREESCALE_COMPONENT=$COMPONENT added to configmap $CONFIGMAP
        oc label configmap $CONFIGMAP $THREESCALE_COMPONENT=$COMPONENT
    done
    for SECRET in $(oc get secret | grep $COMPONENT | awk '{print $1}')
    do
        if [ $COMPONENT == zync ]
        then 
            echo Label $THREESCALE_COMPONENT=zync added to secret zync
            oc label secret zync $THREESCALE_COMPONENT=zync
        else
            echo Label $THREESCALE_COMPONENT=$COMPONENT added to secret $SECRET
            oc label secret $SECRET $THREESCALE_COMPONENT=$COMPONENT
        fi
    done
    for IMAGESTREAM in $(oc get imagestream | grep $COMPONENT | awk '{print $1}')
    do
        if [ $COMPONENT == zync ]
        then 
            oc label imagestream amp-zync $THREESCALE_COMPONENT=zync
            oc label imagestream zync-database-postgresql $THREESCALE_COMPONENT=system
        else
            echo Label $THREESCALE_COMPONENT=$COMPONENT added to secret $SECRET
            oc label secret $SECRET $THREESCALE_COMPONENT=$COMPONENT
        fi
    done
    for IMAGESTREAMTAG in in $(oc get imagestreamtag | grep $COMPONENT | awk '{print $1}')
    do
        if [ $COMPONENT == zync ]
        then 
            oc label imagestreamtag amp-zync:2.6 $THREESCALE_COMPONENT=zync
            oc label imagestreamtag amp-zync:2.7 $THREESCALE_COMPONENT=zync
            oc label imagestreamtag amp-zync:2.8 $THREESCALE_COMPONENT=zync
            oc label imagestreamtag amp-zync:2.9 $THREESCALE_COMPONENT=zync
            oc label imagestreamtag amp-zync:latest $THREESCALE_COMPONENT=zync
            oc label imagestreamtag zync-database-postgresql:2.6 $THREESCALE_COMPONENT=system
            oc label imagestreamtag zync-database-postgresql:2.7 $THREESCALE_COMPONENT=system
            oc label imagestreamtag zync-database-postgresql:2.8 $THREESCALE_COMPONENT=system
            oc label imagestreamtag zync-database-postgresql:2.9 $THREESCALE_COMPONENT=system
            oc label imagestreamtag zync-database-postgresql:latest $THREESCALE_COMPONENT=system
        else
            echo Label $THREESCALE_COMPONENT=$COMPONENT added to secret $SECRET
            oc label secret $SECRET $THREESCALE_COMPONENT=$COMPONENT
        fi
    done

done

# ConfigMap exceptions
oc label configmap mysql-extra-conf $THREESCALE_COMPONENT=system
oc label configmap mysql-main-conf $THREESCALE_COMPONENT=system
oc label configmap redis-config $THREESCALE_COMPONENT=system

# Route only one route has a label
oc label route backend $THREESCALE_COMPONENT=backend


################################################################################

# Adding the threescale_component_element label

for COMPONENT_ELEMENT in mysql redis production staging listener database cron worker app memcache sidekiq sphinx
do 
    for CONFIGMAP in $(oc get configmap | grep $COMPONENT_ELEMENT | awk '{print $1}')
    do
        echo Label $THREESCALE_COMPONENT_ELEMENT=$COMPONENT_ELEMENT added to configmap $CONFIGMAP 
        oc label configmap $CONFIGMAP $THREESCALE_COMPONENT_ELEMENT=$COMPONENT_ELEMENT 
    done
    for POD in $(oc get po| grep $COMPONENT_ELEMENT | awk '{print $1}')
    do
        echo Label $THREESCALE_COMPONENT_ELEMENT=$COMPONENT_ELEMENT added to pod $POD 
        oc label pod $POD $THREESCALE_COMPONENT_ELEMENT=$COMPONENT_ELEMENT 
    done
    for PVC in $(oc get pvc| grep $COMPONENT_ELEMENT | awk '{print $1}')
    do
        echo Label $THREESCALE_COMPONENT_ELEMENT=$COMPONENT_ELEMENT added to pvc $PVC 
        oc label pvc $PVC $THREESCALE_COMPONENT_ELEMENT=$COMPONENT_ELEMENT 
    done
    for RC in $(oc get replicationController| grep $COMPONENT_ELEMENT | awk '{print $1}')
    do
        echo Label $THREESCALE_COMPONENT_ELEMENT=$COMPONENT_ELEMENT added to replicationController $RC 
        oc label replicationController $RC $THREESCALE_COMPONENT_ELEMENT=$COMPONENT_ELEMENT 
    done
    for DC in $(oc get deploymentconfig | grep $COMPONENT_ELEMENT | awk '{print $1}')
    do
        echo Label $THREESCALE_COMPONENT_ELEMENT=$COMPONENT_ELEMENT added to deploymentconfig $DC 
        oc label deploymentconfig $DC $THREESCALE_COMPONENT_ELEMENT=$COMPONENT_ELEMENT 
    done
    for ENDPOINTS in $(oc get endpoints | grep $COMPONENT_ELEMENT | awk '{print $1}')
    do
        echo Label $THREESCALE_COMPONENT_ELEMENT=$COMPONENT_ELEMENT added to endpoints $ENDPOINTS 
        oc label endpoints $ENDPOINTS $THREESCALE_COMPONENT_ELEMENT=$COMPONENT_ELEMENT 
    done
    for SVC in $(oc get service | grep $COMPONENT_ELEMENT | awk '{print $1}')
    do
        echo Label $THREESCALE_COMPONENT_ELEMENT=$COMPONENT_ELEMENT added to service $SVC 
        oc label service $SVC $THREESCALE_COMPONENT_ELEMENT=$COMPONENT_ELEMENT 
    done
done

# Only one secret needs relabling 
oc lable secret system-smtp $THREESCALE_COMPONENT_ELEMENT=smtp

# Endpoints mostly one offs
# Endpoints:  system-developer:  map[app:3scale-api-management threescale_component:system threescale_component_element:developer-ui]
# Endpoints:  system-master:  map[app:3scale-api-management threescale_component:system threescale_component_element:master-ui]
# Endpoints:  system-provider:  map[app:3scale-api-management threescale_component:system threescale_component_element:provider-ui]

oc lable endpoints system-developer $THREESCALE_COMPONENT_ELEMENT=developer-ui
oc lable endpoints system-master $THREESCALE_COMPONENT_ELEMENT=master-ui
oc lable endpoints system-provider $THREESCALE_COMPONENT_ELEMENT=provider-ui

# Services mostly one offs
# Service:  system-developer:  map[app:3scale-api-management threescale_component:system threescale_component_element:developer-ui]
# Service:  system-master:  map[app:3scale-api-management threescale_component:system threescale_component_element:master-ui]
# Service:  system-provider:  map[app:3scale-api-management threescale_component:system threescale_component_element:provider-ui]

oc lable service system-developer $THREESCALE_COMPONENT_ELEMENT=developer-ui
oc lable service system-master $THREESCALE_COMPONENT_ELEMENT=master-ui
oc lable service system-provider $THREESCALE_COMPONENT_ELEMENT=provider-ui