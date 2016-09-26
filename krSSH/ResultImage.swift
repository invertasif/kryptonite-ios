//
//  ResultImage.swift
//  krSSH
//
//  Created by Alex Grinman on 9/23/16.
//  Copyright © 2016 KryptCo. All rights reserved.
//

import Foundation

enum ResultImage:String {
    case check = "check"
    case x = "x"
    
    var image:UIImage? {
        return UIImage(named: self.rawValue)
    }
}
    