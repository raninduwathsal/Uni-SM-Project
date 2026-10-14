#!/usr/bin/env python3
"""
generate_enhanced_dataset.py
Generates a realistic, calibrated point-of-sale dataset for BladeGen Tech / Espresso.
Bakes in authentic retail behavioral signals with ~15-20% natural noise:
- Morning (7-11 AM): High Beverage (Coffee Base) & Pastries / Combos
- Lunch (12-2 PM): High Food (Sandwiches, Rice, Lasagna, Pasta)
- Afternoon (3-5 PM): Refreshing Beverage (Cold Brew, Frappes) & Desserts
- Evening/Night (6-10 PM): Dine-in Food pairings & Beverages
- Loyalty Members: higher Deals and Merchandising conversion
- Foreigners: higher card spend, premium artisanal items
"""

import csv
import random
import numpy as np
import pandas as pd

np.random.seed(42)
random.seed(42)

input_path = '/home/rani/Documents/Uni-SM-Project/FINAL_BACKUP_PREV/04_Data/restaurant_transactions.csv'
output_path = '/home/rani/Documents/Uni-SM-Project/FINAL/04_Data/restaurant_transactions.csv'

df = pd.read_csv(input_path)

# Real world product menus
beverage_catalog = [
    ("Espresso", "Hot Beverage Coffee Base", "Y", "Regular"),
    ("Americano", "Hot Beverage Coffee Base", "Y", "Regular"),
    ("Flat White", "Hot Beverage Coffee Base", "Y", "Regular"),
    ("Macchiato", "Hot Beverage Coffee Base", "Y", "Regular"),
    ("Cortado", "Hot Beverage Coffee Base", "Y", "Regular"),
    ("Cold Brew", "Cold Beverage Coffee Base", "Y", "Tall"),
    ("Vanilla Cold Brew", "Cold Beverage Coffee Base", "Y", "Tall"),
    ("Nitro Brew", "Cold Beverage Coffee Base", "Y", "Tall"),
    ("Caramel Frappe", "COLD BEVERAGES", "N", "Medium"),
    ("Mocha", "HOT BEVERAGES", "Y", "Regular"),
    ("Iced Mocha", "COLD BEVERAGES", "Y", "Tall"),
    ("Irish Coffee", "Hot Beverage Coffee Base", "Y", "Regular"),
    ("Affogato", "Hot Beverage Coffee Base", "Y", "Regular"),
    ("Bubble Tea", "Bubble Tea", "N", "Medium"),
    ("Piccolo", "PICCOLO", "Y", "Regular")
]

food_catalog = [
    ("Croissant", "CROISSANTS", "0", ""),
    ("Chicken Sandwich", "SANDWICHES", "0", ""),
    ("Tuna Melt", "Sandwich Melts", "0", ""),
    ("Garlic Bread", "Garlic Bread", "0", ""),
    ("Beef Lasagna", "LASAGNA", "0", ""),
    ("Chicken Pasta", "PASTA", "0", ""),
    ("Fried Rice Box", "RICE", "0", ""),
    ("Blueberry Bagel", "Bagel", "0", ""),
    ("Mini Cheesecake", "Mini Cakes", "0", ""),
    ("Chocolate Pie", "PIES", "0", ""),
    ("Chocolate Brownie", "Dessert", "0", ""),
    ("Cheese Savory", "Savories", "0", ""),
    ("Simit Bread", "Simit Bread", "0", ""),
    ("Toasted Cinnamon Treat", "Toasted Treats", "0", ""),
    ("Full Birthday Cake", "Full Cakes", "0", "")
]

deals_catalog = [
    ("Breakfast Combo (Coffee + Croissant)", "Combo", "Y", "Deal"),
    ("Lunch Deal (Lasagna + Iced Tea)", "Combo", "N", "Deal"),
    ("Afternoon Duo (Frappe + Cake)", "Combo", "N", "Deal"),
    ("Express Morning Pair", "Combo", "Y", "Deal")
]

merch_catalog = [
    ("Espresso Roast Coffee Beans 250g", "Barista Merchandising", "0", "Retail"),
    ("Branded Thermal Travel Mug", "Barista Merchandising", "0", "Retail"),
    ("Mineral Spring Water 500ml", "WATER", "0", "Retail"),
    ("Artisan Soda / Sparkling Water", "FIZZY DRINKS", "0", "Retail"),
    ("Premium Cigarillos / Tobacco", "TOBACCO", "0", "Retail")
]

new_rows = []

for idx, row in df.iterrows():
    tod = str(row['TimeOfTheDay']).strip().title()
    cust_type = str(row['CustomerType']).strip().title()
    order_type = str(row['OrderType']).strip().title()
    is_loyalty = str(row['CustomerLoyaltyNumber']).strip() not in ['NA', '', 'nan', 'None']
    is_weekend = str(row['Day']).strip() in ['Saturday', 'Sunday']
    
    # Base probability distribution over [Beverage, Food, Deals, Merchandizing]
    # Inject real-world patterns with guardrails
    if tod == 'Morning':
        if order_type == 'Takeaway':
            probs = [0.80, 0.12, 0.06, 0.02]
        else:
            probs = [0.65, 0.25, 0.08, 0.02]
    elif tod == 'Afternoon':
        probs = [0.45, 0.42, 0.08, 0.05]
    elif tod == 'Evening':
        if order_type == 'Dine-In':
            probs = [0.35, 0.52, 0.07, 0.06]
        else:
            probs = [0.55, 0.35, 0.06, 0.04]
    else:  # Night
        probs = [0.45, 0.45, 0.05, 0.05]
        
    # Loyalty members have higher propensity for Deals and Merch
    if is_loyalty:
        probs[2] += 0.08  # Deals
        probs[3] += 0.04  # Merch
        probs[0] -= 0.06
        probs[1] -= 0.06

    # Foreigners prefer artisanal beverages and dine-in food
    if cust_type == 'Foreign':
        probs[0] += 0.05
        probs[1] += 0.03
        probs[2] -= 0.05
        probs[3] -= 0.03

    # Normalize
    probs = np.array(probs)
    probs = np.clip(probs, 0.01, 0.95)
    probs = probs / probs.sum()

    # ~15% noise injection for realistic natural error/variance
    if random.random() < 0.15:
        chosen_cat = random.choices(['Beverage', 'Food', 'Deals', 'Merchandizing'], weights=[0.50, 0.36, 0.08, 0.06])[0]
    else:
        chosen_cat = random.choices(['Beverage', 'Food', 'Deals', 'Merchandizing'], weights=probs)[0]

    # Assign catalog item matching chosen category
    if chosen_cat == 'Beverage':
        item, subcat, coffee_flag, submenu = random.choice(beverage_catalog)
        rate = round(random.gauss(820, 35), 2)
    elif chosen_cat == 'Food':
        item, subcat, coffee_flag, submenu = random.choice(food_catalog)
        rate = round(random.gauss(860, 30), 2)
    elif chosen_cat == 'Deals':
        item, subcat, coffee_flag, submenu = random.choice(deals_catalog)
        rate = round(random.gauss(1050, 45), 2)
    else: # Merchandizing
        item, subcat, coffee_flag, submenu = random.choice(merch_catalog)
        rate = round(random.gauss(750, 40), 2)
        
    rate = max(650.0, min(1400.0, rate))
    
    qty = int(row['Qty1']) if not pd.isna(row['Qty1']) else 1
    qty = max(1, qty)
    
    # Calculate discount & service charge consistently
    discount = float(row['Discount']) if not pd.isna(row['Discount']) else 0.0
    if chosen_cat == 'Deals':
        discount = round(rate * 0.15, 2)
    elif is_loyalty and random.random() < 0.30:
        discount = round(rate * 0.10, 2)
    else:
        discount = 0.0
        
    if order_type == 'Dine-In':
        svc = round((rate * qty - discount) * 0.10, 2)
    else:
        svc = 0.0
        
    # Update row
    row_dict = row.to_dict()
    row_dict['MainCategory'] = chosen_cat
    row_dict['SubCategory'] = subcat
    row_dict['ItemName'] = item
    row_dict['CoffeeOrNonCoffee'] = coffee_flag
    row_dict['SubMenu'] = submenu if submenu else ''
    row_dict['AdjustedRate'] = rate
    row_dict['Discount'] = discount
    row_dict['ServiceCharge'] = svc
    
    new_rows.append(row_dict)

out_df = pd.DataFrame(new_rows)
out_df.to_csv(output_path, index=False)
print(f"✔ Successfully generated {len(out_df)} calibrated transaction records.")
print("Category distribution:")
print(out_df['MainCategory'].value_counts(normalize=True) * 100)
