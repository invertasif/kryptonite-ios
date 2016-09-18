//
//  PersistanceManager.swift
//  krSSH
//
//  Created by Alex Grinman on 9/13/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation
import CoreData

private var sharedLogManager:LogManager?
class LogManager {
    
    private var mutex = Mutex()
    private var logs:[SignatureLog] = []
    private var sigs:[String:Bool] = [:]

    init() {
        self.logs = []
        
        let fetchRequest:NSFetchRequest<NSFetchRequestResult>  = NSFetchRequest(entityName: "SignatureLog")
        
        do {
            let results =
                try self.managedObjectContext.fetch(fetchRequest) as? [NSManagedObject]
            
            for managedLog in (results ?? []) {
                guard
                    let session = managedLog.value(forKey: "session") as? String,
                    let digest = managedLog.value(forKey: "digest") as? String,
                    let signature = managedLog.value(forKey: "signature") as? String,
                    let date = managedLog.value(forKey: "date") as? Date
                else {
                    continue
                }
                
                if sigs[digest] == nil {
                    logs.append(SignatureLog(session: session, digest: digest, signature: signature, date: date))
                    sigs[digest] = true
                }
                
            }
            
        } catch {
            log("could not fetch signature logs: \(error)")
        }

    }
    
    class var shared:LogManager {
        guard let lm = sharedLogManager else {
            sharedLogManager = LogManager()
            return sharedLogManager!
        }
        return lm
    }
    
    var all:[SignatureLog] {
        var theLogs:[SignatureLog] = []
        mutex.lock {
            theLogs = [SignatureLog](self.logs)
        }
        return theLogs
    }
    
    func save(theLog:SignatureLog) {
        mutex.lock()
        
        guard sigs[theLog.digest] == nil else {
            mutex.unlock()
            return
        }
        
        sigs[theLog.digest] = true
        
        mutex.unlock()
        
        guard
            let entity =  NSEntityDescription.entity(forEntityName: "SignatureLog", in: managedObjectContext)
        else {
            return
        }
        
        let logEntry = NSManagedObject(entity: entity, insertInto: managedObjectContext)
        
        // set attirbutes
        logEntry.setValue(theLog.session, forKey: "session")
        logEntry.setValue(theLog.signature, forKey: "signature")
        logEntry.setValue(theLog.date, forKey: "date")
        
        //4
        do {
            try self.managedObjectContext.save()
            
            mutex.lock {
                logs.append(theLog)
            }
            
        } catch let error  {
            log("Could not save signature log: \(error)", .error)
        }
    }
    
    lazy var applicationDocumentsDirectory: URL = {
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return urls[urls.count-1]
    }()
    
    lazy var managedObjectModel: NSManagedObjectModel = {
        let modelURL = Bundle.main.url(forResource:"krSSH", withExtension: "momd")!
        return NSManagedObjectModel(contentsOf: modelURL)!
    }()
    
    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator = {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        let url = self.applicationDocumentsDirectory.appendingPathComponent("KrSSHCoreData.sqlite")
        do {
            try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: nil)
        } catch let e {
            log("Persistance manager error: \(e)", .error)
        }
        
        return coordinator
    }()
    
    lazy var managedObjectContext: NSManagedObjectContext = {
        let coordinator = self.persistentStoreCoordinator
        var managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = coordinator
        return managedObjectContext
    }()
    
    
    
    
    // MARK: - Core Data Saving support
    
    func saveContext () {
        if managedObjectContext.hasChanges {
            do {
                try managedObjectContext.save()
            } catch {
                log("Persistance manager save error: \(error)", .error)

            }
        }
    }

}

extension Session {
    var lastAccessed:Date? {
        return LogManager.shared.all.filter({ $0.session == self.id }).sorted(by: { $0.date < $1.date }).last?.date
    }
}