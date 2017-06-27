## WARNING !!! experimental changes

## Running the sample program
##### Terminal Window 1
```
cd FabricNodeApp1.0

./runApp.sh

```
 
* This launches the required network on your local machine
* Installs the "rc1" tagged node modules
* And, starts the node app on PORT 4000

##### Terminal Window 2


In order for the following shell script to properly parse the JSON, you must install [jq](https://stedolan.github.io/jq/):

With the application started in terminal 1, next, test the APIs by executing the script - **testAPIs.sh**:
```
cd FabricNodeApp1.0

./test_10ch_10cc.sh

```

#### Cleanup:

Once the tests are completed, cleanup the network and crypto material using the below command

```
./runApp.sh -m stop
OR
./runApp.sh -m down
```

**NOTE** : There are two more options available **start** and **restart** (restart is default)
