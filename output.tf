#This will print the website URL description

output "website_url" {
  description = "URL website"
  value = aws_s3_bucket_website_configuration.hosting_bucket_website_configuration.website_endpoint
}