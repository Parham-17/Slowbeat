//
//  Pulse_WidgetBundle.swift
//  Pulse Widget
//
//  Created by Parham Kharbasi on 17/05/26.
//

import WidgetKit
import SwiftUI

@main
struct Pulse_WidgetBundle: WidgetBundle {
    var body: some Widget {
        Pulse_Widget()
        Pulse_WidgetLiveActivity()
    }
}
