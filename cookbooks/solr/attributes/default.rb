# Set the version of Solr to install
default[:solr_version] = "3.6.2"

# Set the name of utility instance on which to run Solr.
# Leave blank to install on all utility and solo instances.
default[:solr_utility_name] = "utility"

# Set to true to configure Sunspot for Rails applications on this environment
default[:solr_sunspot] = true
