import sqlite3
import json

def create_database():
    # Connect to SQLite database (creates it if it doesn't exist)
    conn = sqlite3.connect('vancouver_restaurants.sqlite')
    cursor = conn.cursor()

    # Create the restaurants table
    cursor.execute('''
    CREATE TABLE IF NOT EXISTS restaurants (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        Name TEXT,
        Address TEXT,
        Website TEXT,
        Description TEXT,
        Type TEXT,
        Cuisine TEXT,
        Hours TEXT,
        Price_Range TEXT
    )
    ''')

    # Restaurant data
    restaurants = [
        {
            "Name": "Okeya Kyujiro",
            "Address": "777 Thurlow St, Vancouver, BC V6E 3V5",
            "Website": "okeyakyujiro.com",
            "Description": "A Kyoto-style omakase kaiseki restaurant with a Michelin star. Chefs in traditional attire prepare elaborate multi-course meals featuring sashimi, grilled items, and delicate desserts in an immersive experience.",
            "Type": "Fine Dining (Kaiseki/Omakase)",
            "Cuisine": "Japanese (Kaiseki)",
            "Hours": "Two seatings nightly (5:30 PM & 8:00 PM); closed Mon",
            "Price_Range": "$$$$ (Kaiseki set menu)"
        },
        {
            "Name": "Masayoshi",
            "Address": "4376 Fraser St, Vancouver, BC V5V 4G3",
            "Website": "masayoshi.ca",
            "Description": "An intimate Michelin-starred sushi restaurant offering omakase experiences with Edomae-style sushi and seasonal Japanese dishes. Limited seats for a personalized journey of nigiri, sashimi, and cooked courses.",
            "Type": "Fine Dining (Sushi Omakase)",
            "Cuisine": "Japanese (Sushi)",
            "Hours": "Tue–Sat 6:00 PM – 10:00 PM; closed Sun & Mon",
            "Price_Range": "$$$$ (~$150+ omakase)"
        },
        {
            "Name": "Kissa Tanto",
            "Address": "263 E Pender St, Vancouver, BC V6A 1T8",
            "Website": "kissatanto.com",
            "Description": "A hidden Michelin-starred gem blending Japanese and Italian cuisine in a retro supper club setting. Known for inventive fusion dishes like carpaccio with yuzu or tonkotsu tagliatelle.",
            "Type": "Upscale Bistro / Bar",
            "Cuisine": "Japanese-Italian Fusion",
            "Hours": "Tue–Sat 5:30 PM – 10:30 PM; closed Sun & Mon",
            "Price_Range": "$$$$ (small plates $15+, mains ~$30–$40)"
        },
        {
            "Name": "iDen & QuanJuDe Beijing Duck House",
            "Address": "2800–2850 Cambie St, Vancouver, BC V5Z 2V5",
            "Website": "idengroup.com/quanjude",
            "Description": "A Vancouver outpost of Beijing's legendary roast duck restaurant, Michelin-starred for exceptional Chinese cuisine. Famous for Peking duck with table-side carving and refined Cantonese & Sichuan dishes.",
            "Type": "Fine Dining",
            "Cuisine": "Chinese (Beijing & Cantonese)",
            "Hours": "Daily 11:30 AM – 3:00 PM; 5:00 PM – 10:00 PM",
            "Price_Range": "$$$$ (Duck tasting menus)"
        },
        {
            "Name": "Burdock & Co.",
            "Address": "2702 Main St, Vancouver, BC V5T 3E8",
            "Website": "burdockandco.com",
            "Description": "A cozy Michelin-starred spot championing farm-to-table dining by Chef Andrea Carlson. Serves organic, locally sourced dishes with a rustic yet refined flair; beloved for seasonal small plates and natural wines.",
            "Type": "Bistro (Farm-to-Table)",
            "Cuisine": "Pacific Northwest / Contemporary Canadian",
            "Hours": "Wed–Sun 5:30 PM – 10:00 PM; closed Mon & Tue",
            "Price_Range": "$$$ (small plates $15–$30)"
        },
        {
            "Name": "Barbara",
            "Address": "305 E Pender St, Vancouver, BC V6A 1T8",
            "Website": "restaurantbarbara.com",
            "Description": "An 8-seat micro restaurant in Chinatown that earned a Michelin star for its hyper-local tasting menu. Each course is crafted by Chef Patrick Hennessy in front of guests for an intimate chef's-table experience.",
            "Type": "Fine Dining (Chef's Tasting Counter)",
            "Cuisine": "Contemporary / Pacific Northwest",
            "Hours": "Wed–Sun from 5:30 PM (two seatings); closed Mon & Tue",
            "Price_Range": "$$$$ (~$120 tasting menu)"
        },
        {
            "Name": "AnnaLena",
            "Address": "1809 W 1st Ave, Vancouver, BC V6J 5B8",
            "Website": "annalena.ca",
            "Description": "A Michelin-starred Kitsilano gem offering playful contemporary Canadian cuisine with inventive dishes and artistic presentation, blending local West Coast ingredients with avant-garde techniques.",
            "Type": "Fine Dining (Intimate Bistro)",
            "Cuisine": "Contemporary Canadian",
            "Hours": "Wed–Sun 5:00 PM – 11:00 PM; closed Mon & Tue",
            "Price_Range": "$$$$ (prix-fixe or tasting menu)"
        },
        {
            "Name": "Published on Main",
            "Address": "3593 Main St., Vancouver, BC V5V 3N4",
            "Website": "publishedonmain.com",
            "Description": "An innovative, upscale restaurant with retro-chic decor, known for carefully sourced seasonal cuisine and creative tasting menus. Honored as one of Vancouver's first Michelin-starred spots.",
            "Type": "Fine Dining (Contemporary/Seasonal)",
            "Cuisine": "Pacific Northwest Contemporary",
            "Hours": "Mon–Sun: 5:00 PM – 11:00 PM",
            "Price_Range": "$$$$ (tasting menus & à la carte)"
        },
        {
            "Name": "St. Lawrence",
            "Address": "269 Powell St., Vancouver, BC V6A 1G3",
            "Website": "stlawrencerestaurant.com",
            "Description": "A cozy 44-seat Québécois/French bistro that earned a Michelin star for refined French-Canadian cooking by Chef Jean-Christophe Poirier. Signature dishes include crispy maple-glazed pig's ears and duck liver mousse éclair.",
            "Type": "Fine Dining Bistro",
            "Cuisine": "French-Canadian (Québécois)",
            "Hours": "Tue–Sun 5:00 PM – 10:30 PM; closed Mon",
            "Price_Range": "$$$$ (tasting menu ~$125/person)"
        },
        {
            "Name": "Phnom Penh",
            "Address": "244 E Georgia St, Vancouver, BC V6A 1Z7",
            "Website": "",
            "Description": "A Chinatown institution for Cambodian-Vietnamese cuisine. Legendary for butter beef, garlic butter chicken wings, and bold Southeast Asian flavors. Always a line-up.",
            "Type": "Casual Family Restaurant",
            "Cuisine": "Cambodian & Vietnamese",
            "Hours": "Wed–Mon 10:00 AM – 9:00 PM; closed Tue",
            "Price_Range": "$$ (dishes ~$10–$20)"
        },
        {
            "Name": "Maenam",
            "Address": "1938 W 4th Ave, Vancouver, BC V6J 1M5",
            "Website": "maenam.ca",
            "Description": "Modern Thai cuisine by Chef Angus An, featuring vibrant street-food-inspired flavors like green papaya salad, massaman curry, and whole fried fish with a contemporary twist.",
            "Type": "Upscale Casual",
            "Cuisine": "Thai",
            "Hours": "Daily 5:00 PM – 10:00 PM; Fri–Sun 11:30 AM – 2:30 PM (lunch)",
            "Price_Range": "$$–$$$ (curries ~$22)"
        },
        {
            "Name": "Vij's",
            "Address": "3106 Cambie St, Vancouver, BC V5Z 2W2",
            "Website": "vijs.ca",
            "Description": "Groundbreaking Indian-fusion by Chef Vikram Vij with a no-reservations policy. Famous for creative spice blends, lamb 'popsicles' in fenugreek cream curry, and a warm, lively atmosphere.",
            "Type": "Upscale Casual",
            "Cuisine": "Indian Fusion",
            "Hours": "Daily 5:00 PM – 10:00 PM (no reservations)",
            "Price_Range": "$$$ (mains ~$30)"
        },
        {
            "Name": "Le Crocodile",
            "Address": "909 Burrard St #100, Vancouver, BC V6Z 2N2",
            "Website": "lecrocodilerestaurant.com",
            "Description": "A legendary French restaurant operating for over 30 years, revered for classic French haute cuisine like Alsatian onion tart, foie gras, Dover sole, and impeccable soufflés.",
            "Type": "Fine Dining",
            "Cuisine": "French",
            "Hours": "Mon–Fri 11:30 AM – 2:00 PM; Mon–Sat 5:00 PM – 10:00 PM; closed Sun",
            "Price_Range": "$$$$ (apps ~$20+, mains $40+)"
        },
        {
            "Name": "Botanist",
            "Address": "1038 Canada Pl (Fairmont Pacific Rim), Vancouver, BC V6C 0B9",
            "Website": "botanistrestaurant.com",
            "Description": "A botanical-themed fine dining restaurant offering innovative Pacific Northwest cuisine and award-winning cocktails. Seasonal dishes, lush decor, and a world-renowned cocktail bar.",
            "Type": "Fine Dining",
            "Cuisine": "Pacific Northwest / Contemporary",
            "Hours": "Breakfast 7:00 AM – 11:00 AM; Dinner Daily 5:00 PM – 10:00 PM; Weekend brunch 11:00 AM – 2:00 PM",
            "Price_Range": "$$$$ (entrees $35–$50)"
        },
        {
            "Name": "Five Sails Restaurant",
            "Address": "999 Canada Place #410 (Pan Pacific Hotel), Vancouver, BC V6C 3B5",
            "Website": "glowbalgroup.com/fivesails",
            "Description": "Elegant waterfront dining at Canada Place with panoramic views and European-inspired cuisine. Known for lobster bisque, mushroom tagliatelle, premium steaks, and romantic special-occasion vibe.",
            "Type": "Fine Dining (Scenic Waterfront)",
            "Cuisine": "French Fusion / European",
            "Hours": "Wed–Sun 5:30 PM – 10:00 PM; closed Mon & Tue",
            "Price_Range": "$$$$ (mains ~$45–$60)"
        },
        {
            "Name": "Blue Water Cafe",
            "Address": "1095 Hamilton St, Vancouver, BC V6B 5T4",
            "Website": "bluewatercafe.net",
            "Description": "Widely recognized as Vancouver's top seafood destination in a trendy Yaletown heritage warehouse. Offers a raw bar, sushi, and Ocean Wise seafood, plus fine dining service in a stylish setting.",
            "Type": "Fine Dining & Raw Bar",
            "Cuisine": "Seafood (West Coast)",
            "Hours": "Daily: Bar from 4:30 PM; Dinner 5:00 PM – 10:30 PM (to 11:30 PM Thu–Sat)",
            "Price_Range": "$$$$ (entrees ~$40+)"
        },
        {
            "Name": "Nightingale",
            "Address": "1017 W Hastings St, Vancouver, BC V6E 0C4",
            "Website": "hawknightingale.com",
            "Description": "A stylish two-level restaurant by David Hawksworth serving modern Canadian small plates, wood-fired pizzas, and farm-to-table dishes. Chic ambiance for after-work gatherings or dinner dates.",
            "Type": "Upscale Casual (Lounge & Restaurant)",
            "Cuisine": "New Canadian / Fusion",
            "Hours": "Daily 11:30 AM – 11:00 PM (late bites on weekends)",
            "Price_Range": "$$$ (small plates $12–$20, mains ~$25–$35)"
        },
        {
            "Name": "Hawksworth Restaurant",
            "Address": "801 W Georgia St, Vancouver, BC V6C 1P7",
            "Website": "hawksworthrestaurant.com",
            "Description": "Award-winning fine dining by Chef David Hawksworth in the Rosewood Hotel Georgia, serving contemporary Canadian cuisine with Asian influences. Known for sablefish, duck, and elegant plating.",
            "Type": "Fine Dining (Hotel Restaurant)",
            "Cuisine": "Contemporary Canadian",
            "Hours": "Mon–Fri 11:30 AM – 2:30 PM; Daily 5:00 PM – 10:00 PM",
            "Price_Range": "$$$$ (mains $40+, tasting menu)"
        },
        {
            "Name": "Joe Fortes Seafood & Chop House",
            "Address": "777 Thurlow St (at Robson), Vancouver, BC V6E 3V5",
            "Website": "joefortes.ca",
            "Description": "Iconic Vancouver steak and seafood house known for its oyster bar, classic chops, and rooftop patio. Over 35 years of fresh seafood and steaks in a lively supper-club atmosphere with live piano music.",
            "Type": "Upscale Casual Steakhouse/Seafood",
            "Cuisine": "Steak and Seafood",
            "Hours": "Daily 11:00 AM – 11:00 PM (brunch on weekends, happy hour 4–6 PM)",
            "Price_Range": "$$$ (entrées ~$25–$50)"
        },
        {
            "Name": "Gotham Steakhouse & Bar",
            "Address": "615 Seymour St, Vancouver, BC V6B 3K3",
            "Website": "gothamsteakhouse.com",
            "Description": "Classic New York-style steakhouse in a 1930s art deco building. Known for prime USDA steaks, old-school luxury, and live jazz piano in the lounge.",
            "Type": "Fine Dining Steakhouse",
            "Cuisine": "Steakhouse",
            "Hours": "Mon–Sat 4:30 PM – 11:00 PM; Sun 4:30 PM – 10:00 PM",
            "Price_Range": "$$$$ (steaks $50+)"
        },
        {
            "Name": "Black + Blue",
            "Address": "1032 Alberni St, Vancouver, BC V6E 1A3",
            "Website": "blackandblue.ca",
            "Description": "Stylish modern steakhouse featuring premier cuts and a glamorous rooftop patio, in-house meat locker, and an extensive wine list. A go-to for wagyu carpaccio, tomahawk steaks, and a high-end vibe.",
            "Type": "Upscale Steakhouse",
            "Cuisine": "Steakhouse / Contemporary Grill",
            "Hours": "Daily 11:30 AM – 11:00 PM",
            "Price_Range": "$$$$ (steaks $45–$100+)"
        },
        {
            "Name": "Tojo's Restaurant",
            "Address": "1133 W Broadway #3, Vancouver, BC V6H 1G1",
            "Website": "tojos.com",
            "Description": "Iconic Japanese fine dining by Chef Hidekazu Tojo, credited with inventing the California roll. Offers omakase experiences blending classic technique with Pacific Northwest influences.",
            "Type": "Fine Dining (Sushi Bar)",
            "Cuisine": "Japanese (Sushi & Omakase)",
            "Hours": "Tue–Sat 5:00 PM – 10:00 PM; closed Sun & Mon",
            "Price_Range": "$$$$ (omakase $150+)"
        },
        {
            "Name": "Miku",
            "Address": "200 Granville St #70, Vancouver, BC V6C 1S4",
            "Website": "mikurestaurant.com",
            "Description": "High-end Japanese dining overlooking the waterfront. Pioneers of Aburi sushi, with scenic harbor views, indulgent tasting menus, and artful presentations of sashimi and nigiri.",
            "Type": "Fine Dining (Japanese)",
            "Cuisine": "Japanese (Sushi & Seafood)",
            "Hours": "Mon–Fri 11:30 AM – 10:00 PM; Sat–Sun 5:00 PM – 10:00 PM",
            "Price_Range": "$$$$ (platter ~$30+, tasting ~$100)"
        },
        {
            "Name": "Minami",
            "Address": "1118 Mainland St, Vancouver, BC V6B 2T9",
            "Website": "minamirestaurant.com",
            "Description": "Stylish Yaletown restaurant famous for Aburi (flame-seared) sushi and creative Japanese-West Coast fusion. Sister to Miku, offering pressed oshi sushi and inventive cocktails.",
            "Type": "Upscale Casual (Izakaya/Sushi)",
            "Cuisine": "Japanese (Aburi Sushi, Fusion)",
            "Hours": "Daily 11:30 AM – 3:00 PM; 5:00 PM – 10:00 PM",
            "Price_Range": "$$$ (sushi ~$18+, mains $25+)"
        },
        {
            "Name": "Boulevard Kitchen & Oyster Bar",
            "Address": "845 Burrard St (Sutton Place Hotel), Vancouver, BC V6Z 2K6",
            "Website": "boulevardvancouver.ca",
            "Description": "Elegant seafood-centric fine dining with a modern vibe. Luxurious raw bar, expertly prepared seafood, and premium steaks. Extensive wine program; Michelin recommended.",
            "Type": "Fine Dining / Oyster Bar",
            "Cuisine": "Seafood & Continental",
            "Hours": "Daily 11:30 AM – 11:00 PM (weekend brunch 11:00 AM – 3:00 PM)",
            "Price_Range": "$$$$ (mains $35–$60)"
        },
        {
            "Name": "PiDGiN",
            "Address": "350 Carrall St, Vancouver, BC V6B 2J3",
            "Website": "pidginyvr.com",
            "Description": "Trendy Gastown spot serving French-Asian fusion small plates and inventive cocktails. Known for pork belly, miso-sake sablefish, truffle dashi custard, and a modern artsy interior.",
            "Type": "Trendy Bistro/Bar",
            "Cuisine": "French-Asian Fusion",
            "Hours": "Mon–Sat 5:00 PM – 12:00 AM; Sun 5:00 PM – 11:00 PM",
            "Price_Range": "$$$ (plates $15–$25)"
        },
        {
            "Name": "L'Abattoir",
            "Address": "217 Carrall St, Vancouver, BC V6B 2J2",
            "Website": "labattoir.ca",
            "Description": "Gastown restaurant merging French-inspired West Coast cuisine with a stylish bar program. Refined cooking, chic ambiance, popular for duck confit and brunch French toast.",
            "Type": "Upscale Bistro/Bar",
            "Cuisine": "French Pacific Northwest",
            "Hours": "Daily 5:30 PM – 10:00 PM; Weekend brunch 10:00 AM – 2:00 PM",
            "Price_Range": "$$$ (mains ~$30–$40)"
        },
        {
            "Name": "The Mackenzie Room",
            "Address": "415 Powell St, Vancouver, BC V6A 1G7",
            "Website": "themackenzieroom.com",
            "Description": "Hip farm-to-table restaurant in a rustic-chic space with a changing chalkboard menu. Creative share plates using local ingredients, friendly service, unpretentious vibe.",
            "Type": "Contemporary Casual",
            "Cuisine": "Farm-to-Table / New Canadian",
            "Hours": "Tue–Sat 5:30 PM – late; closed Sun & Mon",
            "Price_Range": "$$$ (small plates $15–$30)"
        },
        {
            "Name": "Ask For Luigi",
            "Address": "305 Alexander St, Vancouver, BC V6A 1C4",
            "Website": "askforluigi.com",
            "Description": "A charming Italian trattoria (Bib Gourmand) serving homemade pastas and hearty plates. Cozy neighborhood vibe, known for ricotta gnocchi, bolognese, and weekend brunch.",
            "Type": "Casual Trattoria",
            "Cuisine": "Italian",
            "Hours": "Daily 5:00 PM – 10:00 PM; Sat–Sun brunch 9:30 AM – 2:00 PM",
            "Price_Range": "$$ (pasta ~$20–$25)"
        },
        {
            "Name": "Japadog (Food Stand)",
            "Address": "899 Burrard St (corner of Smithe), Vancouver, BC",
            "Website": "japadog.com",
            "Description": "Famous street cart fusing Japanese flavors with hot dogs (Terimayo, Kurobuta pork). A must-try Vancouver experience often featuring long lines and unique toppings.",
            "Type": "Food Truck/Street Cart",
            "Cuisine": "Japanese Fusion / Street Food",
            "Hours": "Varies by cart; ~11:00 AM – 6:00 PM",
            "Price_Range": "$ (~$7–$9 per hot dog)"
        }
        # ... More restaurants to be added in next edit
    ]

    # Insert restaurant data
    for restaurant in restaurants:
        cursor.execute('''
        INSERT INTO restaurants (Name, Address, Website, Description, Type, Cuisine, Hours, Price_Range)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''', (
            restaurant['Name'],
            restaurant['Address'],
            restaurant['Website'],
            restaurant['Description'],
            restaurant['Type'],
            restaurant['Cuisine'],
            restaurant['Hours'],
            restaurant['Price_Range']
        ))

    # Commit the changes and close the connection
    conn.commit()
    conn.close()

if __name__ == "__main__":
    create_database()
    print("Database created and populated successfully!") 