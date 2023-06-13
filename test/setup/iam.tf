/**
 * Copyright 2019 Google LLC
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

locals {
  int_required_roles = [
    "roles/owner",
    "roles/iam.serviceAccountUser"
  ]

  folder_required_roles = [
    "roles/resourcemanager.folderAdmin",
    "roles/resourcemanager.projectCreator",
    "roles/resourcemanager.projectDeleter",
    "roles/compute.xpnAdmin",
    "roles/iam.serviceAccountTokenCreator"
  ]

  org_required_roles = [
    "roles/accesscontextmanager.policyAdmin",
    "roles/orgpolicy.policyAdmin"
  ]
}

resource "google_service_account" "int_test" {
  project      = module.project.project_id
  account_id   = "ci-account"
  display_name = "ci-account"
}

resource "google_project_iam_member" "int_test" {
  count = length(local.int_required_roles)

  project = module.project.project_id
  role    = local.int_required_roles[count.index]
  member  = "serviceAccount:${google_service_account.int_test.email}"
}

resource "google_folder_iam_member" "folder_test" {
  count = length(local.folder_required_roles)

  folder = google_folder.ci-iam-folder.id
  role   = local.folder_required_roles[count.index]
  member = "serviceAccount:${google_service_account.int_test.email}"
}


resource "google_organization_iam_member" "org_member" {
  count = length(local.org_required_roles)

  org_id = var.org_id
  role   = local.org_required_roles[count.index]
  member = "serviceAccount:${google_service_account.int_test.email}"
}

resource "google_billing_account_iam_member" "int_billing_admin" {
  billing_account_id = var.billing_account
  role               = "roles/billing.user"
  member             = "serviceAccount:${google_service_account.int_test.email}"
}

resource "google_service_account_key" "int_test" {
  service_account_id = google_service_account.int_test.id
}
