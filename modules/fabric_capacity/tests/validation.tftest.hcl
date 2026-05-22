# Tests that the variable validation rules on var.scheduler reject invalid inputs.
# Each run passes a deliberately invalid value and asserts that planning fails
# with a validation error (expect_failures = [var.scheduler]).
#
# Rules exercised:
#   - pause_time and resume_time must match HH:MM (24-hour, zero-padded)
#   - pause_days and resume_days must contain only full weekday names
mock_provider "azurerm" {}
mock_provider "azuread" {}
mock_provider "time" {}

# pause_time "8:00" is missing the leading zero -- must be "08:00".
run "invalid_pause_time_format" {
  command = plan

  variables {
    basename     = "testcapacity"
    location     = "North Europe"
    sku          = "F2"
    admin_emails = []
    scheduler = {
      pause_time  = "8:00"
      resume_time = "07:00"
    }
  }

  expect_failures = [var.scheduler]
}

# resume_time "7:0" has neither field zero-padded -- must be "07:00".
run "invalid_resume_time_format" {
  command = plan

  variables {
    basename     = "testcapacity"
    location     = "North Europe"
    sku          = "F2"
    admin_emails = []
    scheduler = {
      pause_time  = "20:00"
      resume_time = "7:0"
    }
  }

  expect_failures = [var.scheduler]
}

# pause_days uses abbreviated names ("Mon", "Tue") instead of full names.
run "invalid_pause_day" {
  command = plan

  variables {
    basename     = "testcapacity"
    location     = "North Europe"
    sku          = "F2"
    admin_emails = []
    scheduler = {
      pause_time  = "20:00"
      resume_time = "07:00"
      pause_days  = ["Mon", "Tue"]
    }
  }

  expect_failures = [var.scheduler]
}

# resume_days uses an abbreviated name ("Fri") instead of "Friday".
run "invalid_resume_day" {
  command = plan

  variables {
    basename     = "testcapacity"
    location     = "North Europe"
    sku          = "F2"
    admin_emails = []
    scheduler = {
      pause_time  = "20:00"
      resume_time = "07:00"
      resume_days = ["Fri"]
    }
  }

  expect_failures = [var.scheduler]
}

# ---------------------------------------------------------------------------
# var.usage_autostop validation tests
# ---------------------------------------------------------------------------

# check_interval_hours = 0 is below the minimum of 1.
run "invalid_check_interval_hours_zero" {
  command = plan

  variables {
    basename     = "testcapacity"
    location     = "North Europe"
    sku          = "F2"
    admin_emails = []
    usage_autostop = {
      check_interval_hours  = 0
      idle_threshold_checks = 1
    }
  }

  expect_failures = [var.usage_autostop]
}

# check_interval_hours = 1.5 is not a whole number.
run "invalid_check_interval_hours_fractional" {
  command = plan

  variables {
    basename     = "testcapacity"
    location     = "North Europe"
    sku          = "F2"
    admin_emails = []
    usage_autostop = {
      check_interval_hours  = 1.5
      idle_threshold_checks = 1
    }
  }

  expect_failures = [var.usage_autostop]
}

# idle_threshold_checks = 0 is below the minimum of 1.
run "invalid_idle_threshold_checks_zero" {
  command = plan

  variables {
    basename     = "testcapacity"
    location     = "North Europe"
    sku          = "F2"
    admin_emails = []
    usage_autostop = {
      check_interval_hours  = 1
      idle_threshold_checks = 0
    }
  }

  expect_failures = [var.usage_autostop]
}
