//
//  ViewController.swift
//  MQTTNetworking
//
//  Created by Jon Shier on 6/10/18.
//  Copyright © 2018 Jon Shier. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        MQTT.shared.connect()
    }

}

