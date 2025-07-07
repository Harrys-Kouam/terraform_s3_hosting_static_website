#write the terraform module
terraform {
    required_providers {
      aws = {
        source = "hashicorp/aws"
        version = "~> 4.0"
      }
    }
}

#Creating a resource for uploading the static website
#We will use the module template files
#This modules will pick all the files from /web 
module "template_files" {
    source = "hashicorp/dir/template"

    base_dir = "${path.module}/web"
}


provider "aws" {
    # var. is necessary in front to reference a variable
  region = var.aws_region   
}
#We run terraform init to initialize the providers

# Creating the S3 bucket to source
resource "aws_s3_bucket" "hosting_bucket" {

    #name of the bucket
    bucket = var.bucket_name 
  }
#Right after we run terraform apply to create the s3 bucket

# We create the access control list (ACL) for our S3 bucket
# Setting 'public-read' makes the objects in the bucket publicly readable,
# which is needed to serve a static website from S3 publicly.

#resource "aws_s3_bucket_acl" "hosting_bucket_acl" {
  #bucket = aws_s3_bucket.hosting_bucket.id
  #acl = "public-read"
  
#}

resource "aws_s3_bucket_ownership_controls" "ownership" {
  bucket = aws_s3_bucket.hosting_bucket.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "allow_public_policy" {
  bucket = aws_s3_bucket.hosting_bucket.id

  block_public_acls       = true    # Still block public ACLs
  ignore_public_acls      = true    # Still ignore public ACLs
  block_public_policy     = false   # ALLOW public policies (required for your website)
  restrict_public_buckets = false   # Allow your public policy to apply
}



# We define the S3 bucket policy
# This explicitly allows public 'GetObject' access to all objects in the bucket,
# enabling users to access your static website files via HTTP.
resource "aws_s3_bucket_policy" "hosting_bucket_policy" {
    bucket = aws_s3_bucket.hosting_bucket.id
#You specify .id because aws_s3_bucket_policy needs to know which bucket to attach to,
# and .id gives that identifier (bucket name).
    policy = jsonencode({
        "Version": "2012-10-17",
        "Statement": [
            {
                "Effect": "Allow",
                "Principal": "*",
                "Action": "s3:GetObject",
                "Resource": "arn:aws:s3:::${var.bucket_name}/*"
            }
        ]
    })
}

resource "aws_s3_bucket_website_configuration" "hosting_bucket_website_configuration" {
  bucket = aws_s3_bucket.hosting_bucket.id

  index_document {
    suffix = "index.html"
  }
    
}

#Creating the object resource

resource "aws_s3_object" "hosting_bucket_files" {
  #reference the bucket we will be hosting to
    bucket = aws_s3_bucket.hosting_bucket.id
#this reference the module set above and 
#ask with the help of the module to take every files from the web folder
    for_each = module.template_files.files
  # Key is a required attribute for the s3 object
  # The key (path) under which to store the object in S3
    key = each.key
  #This tells Terraform where to find the file on your machine before uploading.
    content_type = each.value.content_type

    source  = each.value.source_path
    content = each.value.content

    etag = each.value.digests.md5
}