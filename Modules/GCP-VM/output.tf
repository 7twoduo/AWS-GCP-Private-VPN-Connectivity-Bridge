output "instance_id" {
  value = google_compute_instance.vm.id
}

output "instance_name" {
  value = google_compute_instance.vm.name
}

output "private_ip" {
  value = google_compute_instance.vm.network_interface[0].network_ip
}

output "public_ip" {
  value = try(google_compute_instance.vm.network_interface[0].access_config[0].nat_ip, null)
}

output "self_link" {
  value = google_compute_instance.vm.self_link
}