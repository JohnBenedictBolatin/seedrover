// Generated from contracts/shared-workflows.json. Do not edit by hand.
abstract final class SharedWorkflowTerms {
  static const version = 1;
  static const receiveStock = "Receive stock";
  static const issueStock = "Issue stock";
  static const adjustQuantity = "Adjust quantity";
  static const newTotalQuantity = "New total quantity";
  static const recordSale = "Record sale";
  static const itemName = "Item name";
  static const itemNotes = "Item notes";
  static const source = "Source";
  static const reason = "Reason";
  static const notes = "Notes";
  static const dateAndTime = "Date and time";
  static const recordCare = "Record care";
  static const fieldCheck = "Record field check";
  static const observation = "Observation";
  static const looksNormal = "Looks normal";
  static const issueNoticed = "Issue noticed";
  static const transplantedTo = "Transplanted to";
  static const observedGrowthStage = "Observed growth stage";
  static const growthPhotos = "Growth photos";
  static const totalHarvestedWeight = "Total harvested weight (kg)";
  static const destinationInventory = "Destination inventory";
  static const harvestAndClose = "Harvest and close batch";
  static const closeWithoutHarvest = "Close without harvest";
  static const closedWithoutHarvest = "Closed without harvest";
  static const batchCode = "Batch code";
  static const history = "History";
  static const firstName = "First name";
  static const middleInitial = "Middle initial";
  static const lastName = "Last name";
  static const contactNumber = "Contact number";
  static const emailAddress = "Email address";
  static const temporaryPassword = "Temporary password";
  static const confirmNewPassword = "Confirm new password";
  static const accountStatus = "Account status";
  static const active = "Active";
  static const inactive = "Inactive";
  static const signIn = "Sign in";
  static const signOut = "Sign out";
  static const rememberUsername = "Remember username";
  static const keepMeSignedIn = "Keep me signed in";
}

abstract final class SharedWorkflowChoices {
  static const receiptSources = <String>["Harvest Bay", "Greenhouse Sorting", "Field Crate", "Market Return", "Farm-table Prep"];
  static const issueReasons = <String>["Farm-table Dining", "Kitchen Preparation", "Spoilage Removal", "Staff Allocation"];
  static const paymentMethods = <String>["Cash", "GCash", "Bank Transfer", "Card", "Other"];
  static const accountStatuses = <String>["Active", "Inactive"];
  static const fieldCheckObservations = <String>["Looks normal", "Issue noticed"];
}

abstract final class SharedWorkflowRules {
  static const inventoryUnit = "kg";
  static const photoMimeTypes = ["image/jpeg","image/png","image/webp"];
  static const photoMaxBytes = 5242880;
  static const usernamePattern = "^[a-z0-9_]{3,32}\$";
  static const minimumPasswordLength = 8;
  static const contactNumberDigits = 11;
  static const contactNumberPattern = "^[0-9]{11}\$";
}

abstract final class IntentionalPlatformDifferences {
  static const authenticationRemember = "{\"web\":\"Keep me signed in\",\"mobile\":\"Remember username\"}";
  static const rover = "{\"web\":\"Rover monitor\",\"mobile\":\"Rover control\"}";
  static const webOnlySales = "[\"multi-item orders\",\"discounts\"]";
}
