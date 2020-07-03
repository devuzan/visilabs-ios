//
//  RecommendationViewController.swift
//  VisilabsIOS_Example
//
//  Created by Egemen on 24.06.2020.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

import Foundation
import Eureka
import UIKit
import VisilabsIOS


class RecommendationViewController: FormViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        initializeForm()
    }
    
    var filtersSection = Section("FILTERS")
    var filterSections: [Section] = []
    
    private func initializeForm() {
        form +++
        Section("Recommendation".uppercased(with: Locale(identifier: "en_US")))
            
            
        <<< ButtonRow() {
            $0.title = "Test"
        }.onCellSelection { cell, row in
            var properties = [String: String]()
            properties["prop1"] = "prop1val"
            properties["prop1"] = "prop2val"
            var filters = [VisilabsRecommendationFilter]()
            
            Visilabs.callAPI().recommend(zoneID: "6", productCode: "pc", filters: filters, properties: properties){ response in
                if let error = response.error{
                    
                }else{
                    for product in response.products{
                        print(product)
                    }
                }
            }
        }
            
            
        <<< IntRow("zoneId") {
            $0.title = "Zone ID"
            $0.add(rule: RuleRequired(msg: "\($0.tag!) required"))
            $0.add(rule: RuleGreaterThan(min: 0, msg: "\($0.tag!) must be greater than 0"))
            $0.value = 1
        }
        
        <<< TextRow("productCode") {
            $0.title = "Product Code"
            $0.add(rule: RuleRequired(msg: "\($0.tag!) required"))
            $0.placeholder = "Product Code"
            $0.value = "asd-123"
        }
            
        
        
        +++ filtersSection
            
            
        <<< ButtonRow() {
            $0.title = "Add Filter"
        }.onCellSelection { cell, row in
            self.addFilterSection()
        }
            
        
        +++ Section()
        <<< LabelRow() {
            $0.title = "not implemented yet"
            /*
            $0.cell.contentView.backgroundColor = .white
            $0.cell.backgroundColor = .white
            $0.cell.textLabel?.textColor = .black
            $0.cell.textLabel?.textAlignment = .left
 */
            $0.disabled = true
        }
            
        <<< ButtonRow() {
            $0.title = "recommend"
            $0.disabled = true
        }
    }
    
    private func addFilterSection(){
        
        let filterSection = Section("FILTER \(filterSections.count + 1)"){ section in
            section.header = {
                  var header = HeaderFooterView<UIView>(.callback({
                    let view = UILabel(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
                    view.text = "╳"
                    view.textAlignment = .right
                    view.font = .systemFont(ofSize: 20.0, weight: .bold)
                    view.textColor = .red
                    return view
                  }))
                  header.height = { 50 }
                  return header
                }()
        }
        
        
        
        filterSections.append(filterSection)
        print(filtersSection.index)
        form.insert(filterSection, at: filtersSection.index! + filterSections.count)
        
        
    }
    
    private func removeSection(){
        
    }
    

}

