declare module "@salesforce/apex/CloudPrismCatalogController.getPricingItems" {
  export default function getPricingItems(param: {csp: any, searchKey: any, importMonth: any, focusCategory: any, rowLimit: any}): Promise<any>;
}
declare module "@salesforce/apex/CloudPrismCatalogController.getExceptionItems" {
  export default function getExceptionItems(param: {csp: any, searchKey: any, importMonth: any, exceptionStatus: any, rowLimit: any}): Promise<any>;
}
declare module "@salesforce/apex/CloudPrismCatalogController.getDistinctImportMonths" {
  export default function getDistinctImportMonths(param: {schemaName: any}): Promise<any>;
}
declare module "@salesforce/apex/CloudPrismCatalogController.getDistinctFocusCategories" {
  export default function getDistinctFocusCategories(): Promise<any>;
}
declare module "@salesforce/apex/CloudPrismCatalogController.getDistinctExceptionStatuses" {
  export default function getDistinctExceptionStatuses(): Promise<any>;
}
declare module "@salesforce/apex/CloudPrismCatalogController.getPricingChanges" {
  export default function getPricingChanges(param: {monthFrom: any, monthTo: any, csp: any, changeType: any}): Promise<any>;
}
declare module "@salesforce/apex/CloudPrismCatalogController.getExceptionChanges" {
  export default function getExceptionChanges(param: {monthFrom: any, monthTo: any, csp: any, changeType: any}): Promise<any>;
}
declare module "@salesforce/apex/CloudPrismCatalogController.getCatalogChangeRows" {
  export default function getCatalogChangeRows(param: {entity: any, monthFrom: any, monthTo: any, csp: any, changeType: any}): Promise<any>;
}
