// Generated from contracts/shared-workflows.json. Do not edit by hand.
export const sharedWorkflowContractVersion = 1 as const;
export const sharedWorkflowTerms = {
    "receiveStock":  "Receive stock",
    "issueStock":  "Issue stock",
    "adjustQuantity":  "Adjust quantity",
    "newTotalQuantity":  "New total quantity",
    "recordSale":  "Record sale",
    "itemName":  "Item name",
    "itemNotes":  "Item notes",
    "source":  "Source",
    "reason":  "Reason",
    "notes":  "Notes",
    "recordCare":  "Record care",
    "fieldCheck":  "Record field check",
    "observation":  "Observation",
    "looksNormal":  "Looks normal",
    "issueNoticed":  "Issue noticed",
    "transplantedTo":  "Transplanted to",
    "observedGrowthStage":  "Observed growth stage",
    "growthPhotos":  "Growth photos",
    "totalHarvestedWeight":  "Total harvested weight (kg)",
    "destinationInventory":  "Destination inventory",
    "harvestAndClose":  "Harvest and close batch",
    "closeWithoutHarvest":  "Close without harvest",
    "closedWithoutHarvest":  "Closed without harvest",
    "batchCode":  "Batch code",
    "history":  "History",
    "firstName":  "First name",
    "middleInitial":  "Middle initial",
    "lastName":  "Last name",
    "contactNumber":  "Contact number",
    "emailAddress":  "Email address",
    "temporaryPassword":  "Temporary password",
    "confirmNewPassword":  "Confirm new password",
    "accountStatus":  "Account status",
    "active":  "Active",
    "inactive":  "Inactive",
    "signIn":  "Sign in",
    "signOut":  "Sign out",
    "rememberUsername":  "Remember username",
    "keepMeSignedIn":  "Keep me signed in"
} as const;
export const sharedWorkflowChoices = {
    "receiptSources":  [
                           "Harvest Bay",
                           "Greenhouse Sorting",
                           "Field Crate",
                           "Market Return",
                           "Farm-table Prep"
                       ],
    "issueReasons":  [
                         "Farm-table Dining",
                         "Kitchen Preparation",
                         "Spoilage Removal",
                         "Staff Allocation"
                     ],
    "paymentMethods":  [
                           "Cash",
                           "GCash",
                           "Bank Transfer",
                           "Card",
                           "Other"
                       ],
    "accountStatuses":  [
                            "Active",
                            "Inactive"
                        ],
    "fieldCheckObservations":  [
                                   "Looks normal",
                                   "Issue noticed"
                               ]
} as const;
export const sharedWorkflowRules = {
    "inventoryUnit":  "kg",
    "photoMimeTypes":  [
                           "image/jpeg",
                           "image/png",
                           "image/webp"
                       ],
    "photoMaxBytes":  5242880,
    "usernamePattern":  "^[a-z0-9_]{3,32}$",
    "minimumPasswordLength":  8
} as const;
export const intentionalPlatformDifferences = {
    "authenticationRemember":  {
                                   "web":  "Keep me signed in",
                                   "mobile":  "Remember username"
                               },
    "rover":  {
                  "web":  "Rover monitor",
                  "mobile":  "Rover control"
              },
    "webOnlySales":  [
                         "multi-item orders",
                         "discounts",
                         "installments"
                     ]
} as const;
