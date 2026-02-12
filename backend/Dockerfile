# 1. Use an official Python runtime as a parent image
FROM python:3.10-slim

# 2. Set the working directory in the container
WORKDIR /app

# 3. Copy requirements.txt into the container
COPY requirements.txt .

# 4. Install the dependencies
RUN pip install --no-cache-dir -r requirements.txt

# 5. Copy the rest of the code into the container
COPY . .

# 6. Expose port 8080 for Cloud Run
EXPOSE 8080

# 7. Define the command to run your app
CMD ["uvicorn", "api.main:app", "--host", "0.0.0.0", "--port", "8080"]
