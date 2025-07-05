import { formatDistanceToNow } from "date-fns";
import { getProjectBySlug } from "@/lib/redis";
import NavComponent from "@/components/NavComponent";
import ChartComponent from "@/components/ChartComponent";
import ChartButton from "@/components/ChartButton";

export default async function ProjectPage({ params }: { params: { slug: string } }) {
    const project = await getProjectBySlug(params.slug);
    if (!project) {
        return (
            <div className="flex flex-col">
                <NavComponent />
                <div className="py-40 h-full flex-1 flex items-center justify-center">
                    <div className="flex flex-col w-full max-w-3xl">
                        <div className="p-6 max-w-4xl mx-auto">
                            <div className="p-6 text-center">
                                <h3 className="text-xl font-semibold text-black mb-2">Project Not Found</h3>
                                <p className="text-text-secondary mb-6">The project you're looking no longer exist.</p>
                                <div className="flex flex-col w-full gap-3">
                                    <a className="w-full bg-yellow-400 text-white py-3 rounded-full font-semibold hover:bg-yellow-600 transition" href="/">
                                        Go back
                                    </a>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        );
    }

    const data = [
        { name: "9AM", value: 11 },
        { name: "10AM", value: 10.3 },
        { name: "11AM", value: 10.6 },
        { name: "12PM", value: 10.4 },
        { name: "1PM", value: 10.1 },
        { name: "2PM", value: 10.2 },
        { name: "3PM", value: 10.7 },
        { name: "4PM", value: 10.72 },
    ];
    const status = "";

    return (
        <>
            <NavComponent />
            <div className="max-w-5xl mx-auto p-6">
                <div className="py-12">
                    <h1 className="text-3xl font-semibold mb-2">
                        {project.name} (${project.ticker})
                    </h1>
                    <p className="text-xl text-gray-700">${project.price}</p>
                    <div className="h-56 my-4">
                        <ChartComponent data={data} />
                    </div>

                    <div className="flex space-x-4 text-sm text-gray-600 mb-6">
                        {["1H", "1D", "1W", "1M", "MAX"].map((range) => (
                            <ChartButton key={range} variant="ghost" className="px-2 py-1 text-xs font-medium">
                                {range}
                            </ChartButton>
                        ))}
                    </div>

                    <section className="mb-6">
                        <h2 className="text-xl font-semibold mb-2">About</h2>
                        <p className="text-gray-700">{project.description} .</p>
                    </section>

                    <div className="grid grid-cols-2 md:grid-cols-3 gap-6 text-sm text-gray-700">
                        <div>
                            <strong>Creator</strong>
                            <br />
                            <ChartButton variant="ghost" className="px-2 py-1 text-xs font-medium">
                                <img src="https://alfajores.celoscan.io/assets/celo/images/svg/logos/token-light.svg?v=25.6.4.0" alt="celo" className="w-5 h-5 mr-1" />
                                0x0235D...99
                            </ChartButton>
                        </div>
                        <div>
                            <strong>Created</strong>
                            <br />
                            {formatDistanceToNow(new Date(Number(project.createdAt)), { addSuffix: true })}
                        </div>
                        <div>
                            <strong>Status</strong>
                            <br />
                            {project.status}
                        </div>
                        <div>
                            <strong>Market cap</strong>
                            <br />
                            3.10K
                        </div>
                        <div>
                            <strong>Average volume</strong>
                            <br />
                            32.03K
                        </div>
                        <div>
                            <strong>Volume</strong>
                            <br />
                            6.05K
                        </div>
                    </div>
                    <button type="submit" className="w-full bg-yellow-400 text-white py-3 rounded-full font-semibold hover:bg-yellow-600 transition" disabled={status === "loading"}>
                        {status === "loading" ? "Loading..." : "Buy"}
                    </button>
                </div>
            </div>
        </>
    );
}
