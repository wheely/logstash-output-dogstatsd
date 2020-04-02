# encoding: utf-8
require "logstash/outputs/base"
require "logstash/namespace"

# statsd is a network daemon for aggregating statistics, such as counters and timers,
# and shipping over UDP to backend services, such as Graphite or Datadog. The general
# idea is that you send metrics to statsd and every few seconds it will emit the
# aggregated values to the backend. Example aggregates are sums, average and maximum
# values, their standard deviation, etc. This plugin makes it easy to send such
# metrics based on data in Logstash events.
#
# You can learn about statsd here:
#
# * https://codeascraft.com/2011/02/15/measure-anything-measure-everything/[Etsy blog post announcing statsd]
# * https://github.com/etsy/statsd[statsd on github]
#
# Typical examples of how this can be used with Logstash include counting HTTP hits
# by response code, summing the total number of bytes of traffic served, and tracking
# the 50th and 95th percentile of the processing time of requests.
#
# Each metric emitted to statsd has a dot-separated path, a type, and a value. The
# metric path is built from the `namespace` option together with the
# metric name that's picked up depending on the type of metric. All in all, the
# metric path will follow this pattern:
#
#     namespace.metric
#
# With regards to this plugin, the default namespace is "logstash",
# and the metric name depends on what is set as the
# metric name in the `increment`, `decrement`, `timing`, `count`, `set` or `gauge`
# options. In metric paths, colons (":"), pipes ("|") and at signs ("@") are reserved
# and will be replaced by underscores ("_").
#
# Example:
# [source,ruby]
# output {
#   statsd {
#     host => "statsd.example.org"
#     count => {
#       "http.bytes" => "%{bytes}"
#     }
#   }
# }
#
# If run with the configuration above plugin will send the following
# metric to statsd if the current event has 123 in its `bytes` field:
#
#     logstash.http.bytes:123|c
class LogStash::Outputs::Statsd < LogStash::Outputs::Base
  ## Regex stolen from statsd code
  RESERVED_CHARACTERS_REGEX = /[\:\|\@]/
  config_name "dogstatsd"

  # The hostname or IP address of the statsd server.
  config :host, :validate => :string, :default => "localhost"

  # The port to connect to on your statsd server.
  config :port, :validate => :number, :default => 8125

  # The statsd namespace to use for this metric. `%{fieldname}` substitutions are
  # allowed.
  config :namespace, :validate => :string, :default => "logstash"

  # An increment metric. Metric names as array. `%{fieldname}` substitutions are
  # allowed in the metric names.
  config :increment, :validate => :array, :default => []

  # A decrement metric. Metric names as array. `%{fieldname}` substitutions are
  # allowed in the metric names.
  config :decrement, :validate => :array, :default => []

  # A timing metric. `metric_name => duration` as hash. `%{fieldname}` substitutions
  # are allowed in the metric names.
  config :timing, :validate => :hash, :default => {}

  # A count metric. `metric_name => count` as hash. `%{fieldname}` substitutions are
  # allowed in the metric names.
  config :count, :validate => :hash, :default => {}

  # A set metric. `metric_name => "string"` to append as hash. `%{fieldname}`
  # substitutions are allowed in the metric names.
  config :set, :validate => :hash, :default => {}

  # A gauge metric. `metric_name => gauge` as hash. `%{fieldname}` substitutions are
  # allowed in the metric names.
  config :gauge, :validate => :hash, :default => {}

  # The sample rate for the metric.
  config :sample_rate, :validate => :number, :default => 1

  # List of datadog tags for the metric.
  config :dd_tags, :validate => :array, :default => []

  public
  def register
    require "datadog/statsd"
    @client = Datadog::Statsd.new(
      @host,
      @port,
      namespace: @namespace,
      sample_rate: @sample_rate,
    )
  end # def register

  public
  def receive(event)
    @logger.debug? and @logger.debug("Event: #{event}")
    tagz = @dd_tags.map { |v| event.sprintf(v) }
    @increment.each do |metric|
      @client.increment(event.sprintf(metric), tags: tagz)
    end
    @decrement.each do |metric|
      @client.decrement(event.sprintf(metric), tags: tagz)
    end
    @count.each do |metric, val|
      @client.count(event.sprintf(metric), event.sprintf(val), tags: tagz)
    end
    @timing.each do |metric, val|
      @client.timing(event.sprintf(metric), event.sprintf(val), tags: tagz)
    end
    @set.each do |metric, val|
      @client.set(event.sprintf(metric), event.sprintf(val), tags: tagz)
    end
    @gauge.each do |metric, val|
      @client.gauge(event.sprintf(metric), event.sprintf(val), tags: tagz)
    end
  end # def receive
end # class LogStash::Outputs::Statsd
