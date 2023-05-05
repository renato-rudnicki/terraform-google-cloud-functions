/**
 * Copyright 2023 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

data "google_project" "project" {
  project_id = var.project_id
}

module "cloudfunction_bucket" {
  source  = "terraform-google-modules/cloud-storage/google//modules/simple_bucket"
  version = "~>3.4"

  project_id    = var.project_id
  labels        = var.labels
  name          = "gcf-v2-sources-${data.google_project.project.number}-${var.location}"
  location      = var.location
  storage_class = "REGIONAL"
  force_destroy = var.force_destroy

  encryption = {
    default_kms_key_name = var.encryption_key
  }
}

resource "google_eventarc_google_channel_config" "primary" {
  location        = var.location
  name            = "projects/${var.project_id}/locations/${var.location}/googleChannelConfig"
  project         = var.project_id
  crypto_key_name = var.encryption_key
}

resource "google_artifact_registry_repository" "cloudfunction_repo" {
  location      = var.location
  project       = var.project_id
  repository_id = "rep-cloud-function-${var.function_name}"
  description   = "This repo stores de image of the secure cloud function"
  format        = "DOCKER"
  kms_key_name  = var.encryption_key
}

resource "google_cloudbuild_worker_pool" "pool" {
  name     = "workerpool"
  location = var.location
  project  = var.project_id
  worker_config {
    disk_size_gb   = 100
    machine_type   = "e2-standard-8"
    no_external_ip = true
  }
}

module "cloud_function" {
  source = "../../"

  function_name       = var.function_name
  description         = var.function_description
  project_id          = var.project_id
  labels              = var.labels
  function_location   = var.location
  runtime             = var.runtime
  entrypoint          = var.entry_point
  repo_source         = var.repo_source
  build_env_variables = var.build_environment_variables
  event_trigger       = var.event_trigger
  storage_source      = var.storage_source
  service_config      = var.service_config
  docker_repository   = google_artifact_registry_repository.cloudfunction_repo.id

  depends_on = [
    module.cloudfunction_bucket,
    google_eventarc_google_channel_config.primary
  ]
}

// IAM for invoking HTTP functions (roles/cloudfunctions.invoker)
resource "google_cloudfunctions2_function_iam_member" "invokers" {
  location       = var.location
  project        = var.project_id
  cloud_function = module.cloud_function.function_name
  role           = "roles/cloudfunctions.invoker"
  member         = "serviceAccount:${var.event_trigger.service_account_email}"

  depends_on = [
    module.cloud_function
  ]
}
