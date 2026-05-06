output "cluster_name" {
  value = google_container_cluster.main.name
}

output "cluster_location" {
  value = google_container_cluster.main.location
}

output "vpc_name" {
  value = google_compute_network.main.name
}

output "subnet_name" {
  value = google_compute_subnetwork.main.name
}

output "academy_db_connection_name" {
  value = google_sql_database_instance.academy.connection_name
}

output "academy_db_public_ip" {
  value = google_sql_database_instance.academy.public_ip_address
}