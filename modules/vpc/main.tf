data "aws_availability_zones" "available" {}

output "private_subnet_ids" {
  value = "${aws_subnet.private.*.id}"
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/24"
  enable_dns_support   = "true"
  enable_dns_hostnames = "true"
}

resource "aws_subnet" "private" {
  count             = "${length(data.aws_availability_zones.available.names)}"
  cidr_block        = "${cidrsubnet(aws_vpc.main.cidr_block, 3, count.index)}"
  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"
  vpc_id            = "${aws_vpc.main.id}"
}

resource "aws_subnet" "public" {
  count                   = "${length(data.aws_availability_zones.available.names)}"
  cidr_block              = "${cidrsubnet(aws_vpc.main.cidr_block, 3, length(data.aws_availability_zones.available.names) + count.index)}"
  availability_zone       = "${data.aws_availability_zones.available.names[count.index]}"
  vpc_id                  = "${aws_vpc.main.id}"
  map_public_ip_on_launch = true
}

resource "aws_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.main.id}"
}

resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.main.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.gw.id}"
}

resource "aws_eip" "gw" {
  count      = "${length(data.aws_availability_zones.available.names)}"
  vpc        = true
  depends_on = ["aws_internet_gateway.gw"]
}

resource "aws_nat_gateway" "gw" {
  count         = "${length(data.aws_availability_zones.available.names)}"
  subnet_id     = "${element(aws_subnet.public.*.id, count.index)}"
  allocation_id = "${element(aws_eip.gw.*.id, count.index)}"
}

resource "aws_route_table" "private" {
  count  = "${length(data.aws_availability_zones.available.names)}"
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = "${element(aws_nat_gateway.gw.*.id, count.index)}"
  }
}

resource "aws_route_table_association" "private" {
  count          = "${length(data.aws_availability_zones.available.names)}"
  subnet_id      = "${element(aws_subnet.private.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.private.*.id, count.index)}"
}
