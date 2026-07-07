
# locals.tf — Computed values, HTML template, and validation checks


locals {
  # Tags automatically applied to all AWS resources via provider default_tags.
  common_tags = {
    owner = var.owner       
    Name  = var.project_name 
  }

  # Scan the images/ folder and list all .jpg files found on disk.
  image_file_names = fileset("${path.module}/${var.images_dir}", "*.jpg")

  # Build ordered list image1.jpg … image10.jpg (only files that actually exist).
  image_files = [
    for n in range(1, 11) : "image${n}.jpg"
    if contains(local.image_file_names, "image${n}.jpg")
  ]

  # Map file extensions to MIME types for correct Content-Type headers on S3 upload.
  content_types = {
    ".jpg"  = "image/jpeg"
    ".jpeg" = "image/jpeg"
    ".png"  = "image/png"
    ".gif"  = "image/gif"
    ".webp" = "image/webp"
  }

  # Gallery HTML page — matches imageindex.html layout; image cards are generated dynamically.
  index_html_content = <<-HTML
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Image Gallery</title>

    <style>
        body {
            font-family: Arial, sans-serif;
            background: #f4f4f4;
            margin: 30px;
        }

        h1 {
            text-align: center;
        }

        .gallery {
            display: grid;
            grid-template-columns: repeat(5, 1fr);
            gap: 20px;
        }

        .card {
            background: white;
            padding: 10px;
            border-radius: 8px;
            text-align: center;
            box-shadow: 0 2px 6px rgba(0,0,0,0.15);
        }

        img {
            width: 180px;
            height: 120px;
            object-fit: cover;
            border-radius: 4px;
            background: #ddd;
        }

        p {
            margin-top: 8px;
            font-weight: bold;
        }
    </style>
</head>
<body>

<h1>Image Gallery</h1>

<div class="gallery">

%{for index, image_name in local.image_files~}
    <div class="card">
        <img src="/${var.images_dir}/${image_name}" alt="Image ${index + 1}">
        <p>Image ${index + 1}</p>
    </div>

%{endfor~}

</div>

</body>
</html>
  HTML
}

# Validation — fail terraform plan/apply if image count is outside 5–10.
check "image_count" {
  assert {
    # Condition must be true or Terraform stops with the error message below.
    condition     = length(local.image_files) >= 5 && length(local.image_files) <= 10
    error_message = "Keep 5 to 10 .jpg files in the ${var.images_dir}/ directory."
  }
}
