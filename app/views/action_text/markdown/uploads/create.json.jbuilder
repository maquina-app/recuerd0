json.message "File uploaded successfully"
json.fileName @upload.filename.to_s
json.mimetype @upload.content_type
json.fileUrl @upload.slug_path
