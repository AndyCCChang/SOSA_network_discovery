@detail_ary = ("Protocol", "Enclosure", "Mount", "Upgrade", "Raid", "Syncing", "A-Class Link", "NAS Client Link", "Fiber", "Domain", "Cluster");
%detail_list = (
		"Protocol" => ["OK", "warning", "critical"],
		"Enclosure" => ["OK", "warning", "critical"],
		"Mount" => ["OK", "warning", "Not mounted", "warning", "Please reboot to fix mount point"],
		"Upgrade" => ["OK", "Upgrading", "critical"],
		"Raid" => ["OK", "warning", "critical"],
		"Syncing" => ["OK", "Syncing", "Sync failed"],
		"A-Class Link" => ["OK", "warning", "Lost connection"],
		"NAS Client Link" => ["OK", "Default gateway unreachable", "Lost connection"],
		"Fiber" => ["OK", "warning", "Lost connection"],
		"Domain" => ["OK", "Updating user/group list", "LDAP connection failed"],
		"Cluster" => ["OK", "Lost remote node service", "Lost local node service", "warning", "Lost all node service"]
)
