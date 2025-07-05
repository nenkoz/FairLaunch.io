const Redis = require("ioredis");

const redis = new Redis(process.env.REDIS_URL || "redis://localhost:6379");

const names = ["Alice", "Bob", "Carol", "David", "Ella", "Frank", "Grace", "Hank"];
const domains = ["example.com", "mail.com", "demo.org"];
const photos = [
    //
    "https://randomuser.me/api/portraits/women/68.jpg",
    "https://randomuser.me/api/portraits/men/75.jpg",
    "https://randomuser.me/api/portraits/women/43.jpg",
    "https://randomuser.me/api/portraits/men/51.jpg",
    "https://randomuser.me/api/portraits/women/22.jpg",
    "https://randomuser.me/api/portraits/men/12.jpg",
    "https://randomuser.me/api/portraits/women/90.jpg",
    "https://randomuser.me/api/portraits/men/30.jpg",
];

async function seedUsers() {
    const allUserIds = [];

    for (let i = 0; i < names.length; i++) {
        const id = `user-${i + 1}`;
        const name = names[i];
        const email = `${name.toLowerCase()}@${domains[i % domains.length]}`;
        const photo_url = photos[i];
        const age = 18 + Math.floor(Math.random() * 15); // Random age 18–32
        const verified = Math.random() < 0.5 ? "true" : "false";

        await redis.hset(`user:${id}`, {
            id,
            name,
            email,
            photo_url,
            age: age.toString(),
            verified,
        });

        allUserIds.push(id);
    }

    // Reset all_users list and populate it
    await redis.del("all_users");
    if (allUserIds.length > 0) {
        await redis.rpush("all_users", ...allUserIds);
    }

    console.log(`✅ Seeded ${allUserIds.length} users with photos and ages.`);
    process.exit(0);
}

seedUsers().catch((err) => {
    console.error("❌ Failed to seed users:", err);
    process.exit(1);
});
