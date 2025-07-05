"use client";

import { useState } from "react";
import DatePicker from "react-datepicker";
import "react-datepicker/dist/react-datepicker.css";

export default function LaunchDateRangePicker() {
    const [startDate, setStartDate] = useState<Date | null>(null);
    const [endDate, setEndDate] = useState<Date | null>(null);

    return (
        <div className="flex flex-col gap-2">
            <label className="block text-sm text-gray-600 mb-1">Launch Duration</label>

            <div className="flex flex-col gap-2">
                <div className="flex items-center gap-2">
                    <span className="text-sm text-gray-500">Start:</span>
                    <DatePicker selected={startDate} onChange={(date) => setStartDate(date)} showTimeSelect dateFormat="Pp" className="px-3 py-2 border rounded w-full text-sm" placeholderText="Select start time" />
                </div>

                <div className="flex items-center gap-2">
                    <span className="text-sm text-gray-500">End:</span>
                    <DatePicker selected={endDate} onChange={(date) => setEndDate(date)} showTimeSelect dateFormat="Pp" className="px-3 py-2 border rounded w-full text-sm" placeholderText="Select end time" />
                </div>
            </div>
        </div>
    );
}
