defmodule Kafka.Metadata do
  def create_request(client_id, correlation_id) do
    << 3 :: 16, 0 :: 16, correlation_id :: 32, String.length(client_id) :: 16 >> <>
      client_id <> << 0 :: 32 >>
  end

  def parse_response(metadata) do
    << num_brokers :: 32, rest :: binary >> = metadata
    {broker_map, rest} = parse_broker_list(%{}, num_brokers, rest)
    << num_topic_metadata :: 32, rest :: binary >> = rest
    {topic_map, _} = parse_topic_metadata(%{}, num_topic_metadata, rest)
    {broker_map, topic_map}
  end

  defp parse_broker_list(map, 0, rest) do
    {map, rest}
  end

  defp parse_broker_list(map, num_brokers, data) do
    << node_id :: 32, host_len :: 16, host :: size(host_len)-binary, port :: 32, rest :: binary >> = data
    {broker_map, rest} = parse_broker_list(map, num_brokers-1, rest)
    {Map.put(broker_map, node_id, %{host: host, port: port}), rest}
  end

  defp parse_topic_metadata(map, 0, rest) do
    {map, rest}
  end

  defp parse_topic_metadata(map, num_topic_metadata, data) do
    << error_code :: 16, topic_len :: 16, topic :: size(topic_len)-binary, num_partitions :: 32, rest :: binary >> = data
    {partition_map, rest} = parse_partition_metadata(%{}, num_partitions, rest)
    {topic_map, rest} = parse_topic_metadata(map, num_topic_metadata-1, rest)
    {Map.put(topic_map, topic, error_code: error_code, partitions: partition_map), rest}
  end

  defp parse_partition_metadata(map, 0, rest) do
    {map, rest}
  end

  defp parse_partition_metadata(map, num_partitions, data) do
    << error_code :: 16, id :: 32, leader :: 32, num_replicas :: 32, rest :: binary >> = data
    {replicas, rest} = parse_int32_array(num_replicas, rest)
    << num_isr :: 32, rest :: binary >> = rest
    {isrs, rest} = parse_int32_array(num_isr, rest)
    {partition_map, rest} = parse_partition_metadata(map, num_partitions-1, rest)
    {Map.put(partition_map, id, %{error_code: error_code, leader: leader, replicas: replicas, isrs: isrs}), rest}
  end

  defp parse_int32_array(0, rest) do
    {[], rest}
  end

  defp parse_int32_array(num, data) do
    << value :: 32, rest :: binary >> = data
    {values, rest} = parse_int32_array(num-1, rest)
    {[value | values], rest}
  end
end
