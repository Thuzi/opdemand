# OpDemand Library

The OpDemand Library consists of [YAML](http://www.yaml.org/) files used to create cloud stacks inside OpDemand.  By forking, customizing and pushing this library into an OpDemand environment, you can customize configuration fields, pre-seed configuration values and even build custom stacks.

#### Customization Workflow

You'll need to install the OpDemand [command-line client](https://github.com/opdemand/opdemand-cli#readme) to customize your library.  After that the workflow is simple:

1. Clone the [opdemand/opdemand](https://github.com/opdemand/opdemand) repository on GitHub
2. Make your modifications locally
3. Use `opdemand push` to push library changes to your environment
4. Refresh the web console to see your library changes

If you are serious about maintaining a custom library, we highly recommend forking the [opdemand/opdemand](https://github.com/opdemand/opdemand) repository and maintaining your changes in version control.  Pull requests are always welcome!

# Library Concepts and Overview

It's important to understand how the OpDemand library is laid out before you begin customizing it.  The OpDemand library contains three directories:

* **Modules** - Used to define configuration, exports, publishing and monitoring
* **Components** - Used to define a single service that is built using modules
* **Templates** - Used to define a template stack that contains multiple services

## Modules

There are 4 types of OpDemand modules which are all defined using YAML.

#### Config Modules

Config modules define a [set of fields](https://github.com/opdemand/opdemand/blob/master/modules/config/ec2-instance.yaml#L10) that are used to configure an individual service and render configuration widgets in OpDemand's web console.  The following keys are required for each config field:

* name
* description
* sort
* type

*Supported types include: text, textarea, list, map, boolean, password, clouds, zones, repository_url, repository_key (used with GitHub integration)*

The following keys are optional:

* default - provide a default value for this field
* required - true/false, enforce a non-null by prompting users on deploy actions
* confirm - true/false, make sure the user is prompted once to confirm this value
* editable - a list of states during which this field is editable
* env_key - the name of the environment variable that will contain this value

#### Export Modules

Export modules define a [set of fields](https://github.com/opdemand/opdemand/blob/master/modules/export/ec2-sg.yaml#L5) to export to the environment so that other services may consume those values.  When a service consumes a value exported from another service, this generates a dependency inside OpDemand which informs how environment-level actions will be orchestrated.

#### Publish Modules

Publish modules define a [set of URLs](https://github.com/opdemand/opdemand/blob/master/modules/publish/http.yaml) that (1) will be published to the environment's Monitor tab and (2) will be monitored with health checks defined using an SLA.

The following keys are required for each publish field:

* name
* description
* template

The `template` key is used to define the target URL for publishing and health checks. HTTP, HTTPS and TCP style URLs are supported.  Note the use of [Python-style string formatting](http://docs.python.org/2/library/stdtypes.html#string-formatting-operations) in the template URLs.

The following keys are used to define the health checks for each published URL:

* interval - time in seconds between each health check
* timeout - timeout in seconds before a health check is considered failed
* retries - number of failed checks before the service goes into a **Warning** state
* healthyafter - the number of healthy checks before the service is marked **Active** again

#### Monitor Modules

Monitor modules define how often the service is refreshed at the cloud provider.  Most services can use the [default refresh module](https://github.com/opdemand/opdemand/blob/master/modules/monitor/refresh.yaml) which polls the cloud provider every 3 minutes (180 seconds).  If a change at the cloud provider is detected, the service will be updated and the change will be logged in OpDemand's event stream.

## Components

Components define how individual services are configured and managed inside OpDemand.  Here is the `ec2-instance` component:

	name: EC2 (Instance)
	description: Amazon EC2 Instance
	provider: ec2-instance
	modules:
	  config: [ service, ec2-instance ]
	  export: [ ec2-instance ]
	  monitor: [ refresh ]

* The `provider` value specifies the type of cloud component OpDemand will manage
* The `modules` section defines which modules will be included in this component by default
  * There are two `config` modules included
    * The `service` module contains [default fields](https://github.com/opdemand/opdemand/blob/master/modules/config/service.yaml) needed for every service
    * The `ec2-instance` module contains [configuration fields for EC2 instances](https://github.com/opdemand/opdemand/blob/master/modules/config/ec2-instance.yaml)
  * The `export` module tells this EC2 instance to [export certain values](https://github.com/opdemand/opdemand/blob/master/modules/export/ec2-instance.yaml) to the environment
  * The `monitor` section tells the EC2 instance to refresh from Amazon [every 3 minutes](https://github.com/opdemand/opdemand/blob/master/modules/monitor/refresh.yaml)

## Templates

Templates defines how a stack containing multiple services is configured and managed inside OpDemand.  Templates specify components, which modules they use and any pre-seeded configuration values.  

	name: Node.js
	description: Node.js application including an Elastic Load Balancer, EC2 Instance, Security Group and Key Pair
	components:
	  - component: ec2-elb
	    consumes: [ instance1 ]
	    modules:
	      publish: [ http ]
	  - component: ec2-instance
	    id: instance1
	    consumes: [ keypair, sg ]
	    modules: 
	      config: [ ec2-deploy, git-deploy, ssh, puppet, application, nginx, os ]
	      publish: [ http ]
	    configure:
	      ec2-instance/tags:
	        Name: Node.js App
	      puppet/classes: [ "opdemand::common", "opdemand::app::nodejs", "opdemand::web::nginx" ]
	      application/repository_url: git://github.com/opdemand/example-nodejs-express.git
	      application/name: nodejs
	  - component: ec2-sg
	    id: sg
	    configure:
	      ec2-sg/rules: [ "0.0.0.0/0,tcp,22,22", "0.0.0.0/0,tcp,80,80" ]
	  - component: ec2-keypair
	    id: keypair

The `components` key contains an ordered list of component services.  Each component comes with its default modules and configuration.  You can also add modules to a component when defining the template.  For example, see the many additional `config` modules that are added to the `ec2-instance`.

##### Pre-Seeded Configuration

The `configure` section is where configuration values can be pre-seeded.  To pre-seed the Instance's EC2 region and SSH keys, add the following:

	configure:
	  ec2-instance/region_name: us-west-2
	  ssh/authorized_keys:
	    - ssh-rsa <key1>
	    - ssh-rsa <key2>
	    
Note that the syntax for the `ec2-instance/region_name` and `ssh/authorized_keys` fields are defined by the `ec2-instance` and `ssh` config modules.

#### Template Linker

Most templates contain services that depend on other services.  The linker allows you have services automatically consume configuration values exported by other services.  For example, take the snippet:

	components:
	  - component: ec2-elb
	    consumes: [ instance1 ]
	    modules:
	      publish: [ http ]
	  - component: ec2-instance
	    id: instance1
	    consumes: [ keypair, sg ]

Notice how the `ec2-instance` sets its ID as `instance1` which is then consumed by the `ec2-elb`.  The Instance also consumes the `keypair` and `sg` IDs (defined elsewhere).

When this template is assembled and a stack is created, the linker will ensure that the keypair and security group are automatically attached to the Instance and the instance ID is automatically attached to the Elastic Load Balancer.

## Additional Resources

* [OpDemand Documentation](http://www.opdemand.com/docs/)
* [OpDemand - How It Works](https://www.opdemand.com/how-it-works/)
