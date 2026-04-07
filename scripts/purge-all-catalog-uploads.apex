/**
 * Permanently removes CloudPrism catalog data (imports + pricing + exception lines)
 * to free org storage. Run with:
 *   sf apex run --file scripts/purge-all-catalog-uploads.apex
 *
 * Deletes in chunks (DML limits), then empties the recycle bin per chunk so storage
 * is reclaimed (not just soft-deleted).
 */
Integer totalPi = 0;
Integer totalEx = 0;
Integer totalCi = 0;

Integer guard = 0;
while (guard++ < 10000) {
    List<Pricing_Item__c> piChunk = [SELECT Id FROM Pricing_Item__c LIMIT 10000];
    if (piChunk.isEmpty()) {
        break;
    }
    List<Id> piIds = new List<Id>();
    for (Pricing_Item__c p : piChunk) {
        piIds.add(p.Id);
    }
    delete piChunk;
    if (!piIds.isEmpty()) {
        Database.emptyRecycleBin(piIds);
    }
    totalPi += piChunk.size();
}

guard = 0;
while (guard++ < 10000) {
    List<Exception_Item__c> exChunk = [SELECT Id FROM Exception_Item__c LIMIT 10000];
    if (exChunk.isEmpty()) {
        break;
    }
    List<Id> exIds = new List<Id>();
    for (Exception_Item__c e : exChunk) {
        exIds.add(e.Id);
    }
    delete exChunk;
    if (!exIds.isEmpty()) {
        Database.emptyRecycleBin(exIds);
    }
    totalEx += exChunk.size();
}

guard = 0;
while (guard++ < 1000) {
    List<Catalog_Import__c> ciChunk = [SELECT Id FROM Catalog_Import__c LIMIT 200];
    if (ciChunk.isEmpty()) {
        break;
    }
    List<Id> ciIds = new List<Id>();
    for (Catalog_Import__c c : ciChunk) {
        ciIds.add(c.Id);
    }
    delete ciChunk;
    if (!ciIds.isEmpty()) {
        Database.emptyRecycleBin(ciIds);
    }
    totalCi += ciChunk.size();
}

System.debug(
    LoggingLevel.INFO,
    'Purge complete: Pricing_Item__c=' +
        totalPi +
        ', Exception_Item__c=' +
        totalEx +
        ', Catalog_Import__c=' +
        totalCi
);
