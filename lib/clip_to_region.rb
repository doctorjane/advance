def clip_to_region(p1, p2, lat_column_name, lon_column_name)
  min_lat = [p1[0], p2[0]].min
  max_lat = [p1[0], p2[0]].max
  min_lon = [p1[1], p2[1]].min
  max_lon = [p1[1], p2[1]].max
  %Q|'(row[#{c0(lat_column_name)}]>=#{min_lat} && |+
    %Q|row[#{c0(lat_column_name)}]<=#{max_lat}) && |+
    %Q|(row[#{c0(lon_column_name)}]>=#{min_lon} && |+
    %Q|row[#{c0(lon_column_name)}]<=#{max_lon})'|
end
