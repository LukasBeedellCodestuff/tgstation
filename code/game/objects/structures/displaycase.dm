/obj/structure/displaycase
	name = "display case"
	icon = 'icons/obj/stationobjs.dmi'
	icon_state = "glassbox0"
	desc = "A display case for prized possessions."
	density = TRUE
	anchored = TRUE
	resistance_flags = ACID_PROOF
	armor = list("melee" = 30, "bullet" = 0, "laser" = 0, "energy" = 0, "bomb" = 10, "bio" = 0, "rad" = 0, "fire" = 70, "acid" = 100)
	max_integrity = 200
	integrity_failure = 0.25
	var/obj/item/showpiece = null
	var/obj/item/showpiece_type = null //This allows for showpieces that can only hold items if they're the same istype as this.
	var/alert = TRUE
	var/open = FALSE
	var/openable = TRUE
	var/obj/item/electronics/airlock/electronics
	var/start_showpiece_type = null //add type for items on display
	var/list/start_showpieces = list() //Takes sublists in the form of list("type" = /obj/item/bikehorn, "trophy_message" = "henk")
	var/trophy_message = ""

/obj/structure/displaycase/Initialize()
	. = ..()
	if(start_showpieces.len && !start_showpiece_type)
		var/list/showpiece_entry = pick(start_showpieces)
		if (showpiece_entry && showpiece_entry["type"])
			start_showpiece_type = showpiece_entry["type"]
			if (showpiece_entry["trophy_message"])
				trophy_message = showpiece_entry["trophy_message"]
	if(start_showpiece_type)
		showpiece = new start_showpiece_type (src)
	update_icon()

/obj/structure/displaycase/Destroy()
	if(electronics)
		QDEL_NULL(electronics)
	if(showpiece)
		QDEL_NULL(showpiece)
	return ..()

/obj/structure/displaycase/examine(mob/user)
	. = ..()
	if(alert)
		. += "<span class='notice'>Hooked up with an anti-theft system.</span>"
	if(showpiece)
		. += "<span class='notice'>There's [showpiece] inside.</span>"
	if(trophy_message)
		. += "The plaque reads:\n [trophy_message]"


/obj/structure/displaycase/proc/dump()
	if (showpiece)
		showpiece.forceMove(loc)
		showpiece = null

/obj/structure/displaycase/play_attack_sound(damage_amount, damage_type = BRUTE, damage_flag = 0)
	switch(damage_type)
		if(BRUTE)
			playsound(src.loc, 'sound/effects/glasshit.ogg', 75, TRUE)
		if(BURN)
			playsound(src.loc, 'sound/items/welder.ogg', 100, TRUE)

/obj/structure/displaycase/deconstruct(disassembled = TRUE)
	if(!(flags_1 & NODECONSTRUCT_1))
		dump()
		if(!disassembled)
			new /obj/item/shard( src.loc )
			trigger_alarm()
	qdel(src)

/obj/structure/displaycase/obj_break(damage_flag)
	if(!broken && !(flags_1 & NODECONSTRUCT_1))
		density = FALSE
		broken = 1
		new /obj/item/shard( src.loc )
		playsound(src, "shatter", 70, TRUE)
		update_icon()
		trigger_alarm()

/obj/structure/displaycase/proc/trigger_alarm()
	//Activate Anti-theft
	if(alert)
		var/area/alarmed = get_area(src)
		alarmed.burglaralert(src)
		playsound(src, 'sound/effects/alert.ogg', 50, TRUE)

/obj/structure/displaycase/update_icon()
	var/icon/I
	if(open)
		I = icon('icons/obj/stationobjs.dmi',"glassbox_open")
	else
		I = icon('icons/obj/stationobjs.dmi',"glassbox0")
	if(broken)
		I = icon('icons/obj/stationobjs.dmi',"glassboxb0")
	if(showpiece)
		var/icon/S = getFlatIcon(showpiece)
		S.Scale(17,17)
		I.Blend(S,ICON_UNDERLAY,8,8)
	src.icon = I
	return

/obj/structure/displaycase/attackby(obj/item/W, mob/user, params)
	if(W.GetID() && !broken && openable)
		if(allowed(user))
			to_chat(user,  "<span class='notice'>You [open ? "close":"open"] [src].</span>")
			toggle_lock(user)
		else
			to_chat(user,  "<span class='alert'>Access denied.</span>")
	else if(W.tool_behaviour == TOOL_WELDER && user.a_intent == INTENT_HELP && !broken)
		if(obj_integrity < max_integrity)
			if(!W.tool_start_check(user, amount=5))
				return

			to_chat(user, "<span class='notice'>You begin repairing [src]...</span>")
			if(W.use_tool(src, user, 40, amount=5, volume=50))
				obj_integrity = max_integrity
				update_icon()
				to_chat(user, "<span class='notice'>You repair [src].</span>")
		else
			to_chat(user, "<span class='warning'>[src] is already in good condition!</span>")
		return
	else if(!alert && W.tool_behaviour == TOOL_CROWBAR && openable) //Only applies to the lab cage and player made display cases
		if(broken)
			if(showpiece)
				to_chat(user, "<span class='warning'>Remove the displayed object first!</span>")
			else
				to_chat(user, "<span class='notice'>You remove the destroyed case.</span>")
				qdel(src)
		else
			to_chat(user, "<span class='notice'>You start to [open ? "close":"open"] [src]...</span>")
			if(W.use_tool(src, user, 20))
				to_chat(user,  "<span class='notice'>You [open ? "close":"open"] [src].</span>")
				toggle_lock(user)
	else if(open && !showpiece)
		if(!istype(W, showpiece_type) && showpiece_type)
			to_chat(user, "<span class='notice'>This doesn't belong in this kind of display.</span>")
			return TRUE
		if(user.transferItemToLoc(W, src))
			showpiece = W
			to_chat(user, "<span class='notice'>You put [W] on display.</span>")
			update_icon()
	else if(istype(W, /obj/item/stack/sheet/glass) && broken)
		var/obj/item/stack/sheet/glass/G = W
		if(G.get_amount() < 2)
			to_chat(user, "<span class='warning'>You need two glass sheets to fix the case!</span>")
			return
		to_chat(user, "<span class='notice'>You start fixing [src]...</span>")
		if(do_after(user, 20, target = src))
			G.use(2)
			broken = 0
			obj_integrity = max_integrity
			update_icon()
	else
		return ..()

/obj/structure/displaycase/proc/toggle_lock(mob/user)
	open = !open
	update_icon()

/obj/structure/displaycase/attack_paw(mob/user)
	return attack_hand(user)

/obj/structure/displaycase/attack_hand(mob/user)
	. = ..()
	if(.)
		return
	user.changeNext_move(CLICK_CD_MELEE)
	if (showpiece && (broken || open))
		to_chat(user, "<span class='notice'>You deactivate the hover field built into the case.</span>")
		log_combat(user, src, "deactivates the hover field of")
		dump()
		src.add_fingerprint(user)
		update_icon()
		return
	else
	    //prevents remote "kicks" with TK
		if (!Adjacent(user))
			return
		if (user.a_intent == INTENT_HELP)
			user.examinate(src)
			return
		user.visible_message("<span class='danger'>[user] kicks the display case.</span>", null, null, COMBAT_MESSAGE_RANGE)
		log_combat(user, src, "kicks")
		user.do_attack_animation(src, ATTACK_EFFECT_KICK)
		take_damage(2)

/obj/structure/displaycase_chassis
	anchored = TRUE
	density = FALSE
	name = "display case chassis"
	desc = "The wooden base of a display case."
	icon = 'icons/obj/stationobjs.dmi'
	icon_state = "glassbox_chassis"
	var/obj/item/electronics/airlock/electronics


/obj/structure/displaycase_chassis/attackby(obj/item/I, mob/user, params)
	if(I.tool_behaviour == TOOL_WRENCH) //The player can only deconstruct the wooden frame
		to_chat(user, "<span class='notice'>You start disassembling [src]...</span>")
		I.play_tool_sound(src)
		if(I.use_tool(src, user, 30))
			playsound(src.loc, 'sound/items/deconstruct.ogg', 50, TRUE)
			new /obj/item/stack/sheet/mineral/wood(get_turf(src), 5)
			qdel(src)

	else if(istype(I, /obj/item/electronics/airlock))
		to_chat(user, "<span class='notice'>You start installing the electronics into [src]...</span>")
		I.play_tool_sound(src)
		if(do_after(user, 30, target = src) && user.transferItemToLoc(I,src))
			electronics = I
			to_chat(user, "<span class='notice'>You install the airlock electronics.</span>")

	else if(istype(I, /obj/item/stock_parts/card_reader))
		var/obj/item/stock_parts/card_reader/C = I
		to_chat(user, "<span class='notice'>You start adding [C] to [src]...</span>")
		if(do_after(user, 20, target = src))
			var/obj/structure/displaycase/forsale/sale = new(src.loc)
			if(electronics)
				electronics.forceMove(sale)
				sale.electronics = electronics
				if(electronics.one_access)
					sale.req_one_access = electronics.accesses
				else
					sale.req_access = electronics.accesses
			qdel(src)
			qdel(C)

	else if(istype(I, /obj/item/stack/sheet/glass))
		var/obj/item/stack/sheet/glass/G = I
		if(G.get_amount() < 10)
			to_chat(user, "<span class='warning'>You need ten glass sheets to do this!</span>")
			return
		to_chat(user, "<span class='notice'>You start adding [G] to [src]...</span>")
		if(do_after(user, 20, target = src))
			G.use(10)
			var/obj/structure/displaycase/display = new(src.loc)
			if(electronics)
				electronics.forceMove(display)
				display.electronics = electronics
				if(electronics.one_access)
					display.req_one_access = electronics.accesses
				else
					display.req_access = electronics.accesses
			qdel(src)
	else
		return ..()

//The captains display case requiring specops ID access is intentional.
//The lab cage and captains display case do not spawn with electronics, which is why req_access is needed.
/obj/structure/displaycase/captain
	alert = TRUE
	start_showpiece_type = /obj/item/gun/energy/laser/captain
	req_access = list(ACCESS_CENT_SPECOPS)

/obj/structure/displaycase/labcage
	name = "lab cage"
	desc = "A glass lab container for storing interesting creatures."
	start_showpiece_type = /obj/item/clothing/mask/facehugger/lamarr
	req_access = list(ACCESS_RD)

/obj/structure/displaycase/trophy
	name = "trophy display case"
	desc = "Store your trophies of accomplishment in here, and they will stay forever."
	var/placer_key = ""
	var/added_roundstart = TRUE
	var/is_locked = TRUE

	alert = TRUE
	integrity_failure = 0
	openable = FALSE

/obj/structure/displaycase/trophy/Initialize()
	. = ..()
	GLOB.trophy_cases += src

/obj/structure/displaycase/trophy/Destroy()
	GLOB.trophy_cases -= src
	return ..()

/obj/structure/displaycase/trophy/attackby(obj/item/W, mob/user, params)

	if(!user.Adjacent(src)) //no TK museology
		return
	if(user.a_intent == INTENT_HARM)
		return ..()

	if(user.is_holding_item_of_type(/obj/item/key/displaycase))
		if(added_roundstart)
			is_locked = !is_locked
			to_chat(user, "<span class='notice'>You [!is_locked ? "un" : ""]lock the case.</span>")
		else
			to_chat(user, "<span class='warning'>The lock is stuck shut!</span>")
		return

	if(is_locked)
		to_chat(user, "<span class='warning'>The case is shut tight with an old fashioned physical lock. Maybe you should ask the curator for the key?</span>")
		return

	if(!added_roundstart)
		to_chat(user, "<span class='warning'>You've already put something new in this case!</span>")
		return

	if(is_type_in_typecache(W, GLOB.blacklisted_cargo_types))
		to_chat(user, "<span class='warning'>The case rejects the [W]!</span>")
		return

	for(var/a in W.GetAllContents())
		if(is_type_in_typecache(a, GLOB.blacklisted_cargo_types))
			to_chat(user, "<span class='warning'>The case rejects the [W]!</span>")
			return

	if(user.transferItemToLoc(W, src))

		if(showpiece)
			to_chat(user, "<span class='notice'>You press a button, and [showpiece] descends into the floor of the case.</span>")
			QDEL_NULL(showpiece)

		to_chat(user, "<span class='notice'>You insert [W] into the case.</span>")
		showpiece = W
		added_roundstart = FALSE
		update_icon()

		placer_key = user.ckey

		trophy_message = W.desc //default value

		var/chosen_plaque = stripped_input(user, "What would you like the plaque to say? Default value is item's description.", "Trophy Plaque")
		if(chosen_plaque)
			if(user.Adjacent(src))
				trophy_message = chosen_plaque
				to_chat(user, "<span class='notice'>You set the plaque's text.</span>")
			else
				to_chat(user, "<span class='warning'>You are too far to set the plaque's text!</span>")

		SSpersistence.SaveTrophy(src)
		return TRUE

	else
		to_chat(user, "<span class='warning'>\The [W] is stuck to your hand, you can't put it in the [src.name]!</span>")

	return

/obj/structure/displaycase/trophy/dump()
	if (showpiece)
		if(added_roundstart)
			visible_message("<span class='danger'>The [showpiece] crumbles to dust!</span>")
			new /obj/effect/decal/cleanable/ash(loc)
			QDEL_NULL(showpiece)
		else
			..()

/obj/item/key/displaycase
	name = "display case key"
	desc = "The key to the curator's display cases."

/obj/item/showpiece_dummy
	name = "Cheap replica"

/obj/item/showpiece_dummy/Initialize(mapload, path)
	. = ..()
	var/obj/item/I = path
	name = initial(I.name)
	icon = initial(I.icon)
	icon_state = initial(I.icon_state)

/obj/structure/displaycase/forsale
	name = "vend-a-tray"
	icon = 'icons/obj/stationobjs.dmi'
	icon_state = "laserbox0"
	desc = "A display case with an ID-card swipe, to purchase the contents. Ctrl-Click to purchase the contained item."
	density = FALSE
	max_integrity = 100
	req_access = list(ACCESS_KITCHEN)
	showpiece_type = /obj/item/reagent_containers/food
	alert = FALSE //No, we're not calling the fire department because someone stole your cookie.
	var/sale_price = 20
	var/datum/bank_account/payments_acc = null

/obj/structure/displaycase/forsale/update_icon()	//remind me to fix my shitcode later
	var/icon/I
	if(open)
		I = icon('icons/obj/stationobjs.dmi',"laserboxb0")
	else
		I = icon('icons/obj/stationobjs.dmi',"laserbox0")
	if(broken)
		I = icon('icons/obj/stationobjs.dmi',"laserboxb0")
	if(!showpiece && !open)
		I = icon('icons/obj/stationobjs.dmi',"laserbox_open")
	if(showpiece)
		var/icon/S = getFlatIcon(showpiece)
		S.Scale(17,17)
		I.Blend(S,ICON_UNDERLAY,8,12)
	src.icon = I
	return

/obj/structure/displaycase/forsale/attackby(obj/item/I, mob/living/user, params)
	if(istype(I, /obj/item/card/id))
		var/obj/item/card/id/potential_acc = I
		if(!payments_acc)
			payments_acc = potential_acc.registered_account
			to_chat(user, "<span class='notice'>Vend-a-tray registered. Use a PDA with your ID to change the cost.</span>")
		else if(payments_acc != potential_acc.registered_account)
			to_chat(user, "<span class='warning'>This Vend-a-tray is already registered.</span>")
			return
	if(istype(I, /obj/item/pda))
		var/obj/item/pda/pda = I
		if(pda.id.registered_account != payments_acc)
			to_chat(user, "<span class='notice'>You don't own [src].</span>")
			return
		var/new_price = input("Set the sale price for this vend-a-tray.","new price") as num|null
		if(!new_price || (get_dist(src,user) > 1))
			return
		sale_price = CLAMP(round(new_price, 1), 10, 1000)
		to_chat(user, "<span class='notice'>The cost is now set to [sale_price].</span>")
		return 1
	if(I.tool_behaviour == TOOL_WRENCH && open && user.a_intent == INTENT_HELP )
		if(anchored)
			to_chat(user, "<span class='notice'>You start unsecuring [src]...</span>")
		else
			to_chat(user, "<span class='notice'>You start securing [src]...</span>")
		if(I.use_tool(src, user, 16, volume=50))
			if(QDELETED(I))
				return
			if(anchored)
				to_chat(user, "<span class='notice'>You unsecure [src].</span>")
			else
				to_chat(user, "<span class='notice'>You secure [src].</span>")
			anchored = !anchored
			return
	else if(I.tool_behaviour == TOOL_WRENCH && !open && user.a_intent == INTENT_HELP)
		to_chat(user, "<span class='notice'>[src] must be open to move it.</span>")
		return
	. = ..()

/obj/structure/displaycase/forsale/emag_act(mob/user)
	. = ..()
	payments_acc = null
	req_access = list()
	to_chat(user, "<span class='warning'>[src]'s card reader fizzles and smokes, and the account owner is reset.</span>")

/obj/structure/displaycase/forsale/examine(mob/user)
	. = ..()
	if(showpiece && !open)
		. += "<span class='notice'>[showpiece] is for sale for [sale_price] credits.</span>"

/obj/structure/displaycase/forsale/CtrlClick(mob/user)
	if(ishuman(user))
		var/mob/living/carbon/human/customer = user
		if(!showpiece)
			to_chat(user, "<span class='notice'>There's nothing for sale.</span>")
			return
		if(customer.get_idcard(TRUE))
			var/obj/item/card/id/C = customer.get_idcard(TRUE)
			var/confirm = alert(user, "Purchase [showpiece] for [sale_price]?", "Purchase?", "Confirm", "Cancel")
			if(confirm == "Cancel")
				return
			if(C.registered_account)
				var/datum/bank_account/account = C.registered_account
				if(!account.has_money(sale_price))
					to_chat(user, "<span class='notice'>You do not possess the funds to purchase this.</span>")
					return
				else
					account.adjust_money(-sale_price)
					if(payments_acc)
						payments_acc.adjust_money(sale_price)
					customer.put_in_hands(showpiece)
					to_chat(user, "<span class='notice'>You purchase [showpiece] for [sale_price] credits.</span>")
					icon = 'icons/obj/stationobjs.dmi'
					flick("laserbox_vend", src)
					showpiece = null
					update_icon()

