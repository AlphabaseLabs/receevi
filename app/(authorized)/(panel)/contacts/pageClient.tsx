"use client"

import {
    ColumnDef, getCoreRowModel,
    getFilteredRowModel,
    getPaginationRowModel,
    getSortedRowModel, PaginationState, SortingState, useReactTable, VisibilityState
} from "@tanstack/react-table"
import { MoreHorizontal } from "lucide-react"
import * as React from "react"

import { Button } from "@/components/ui/button"
import { Checkbox } from "@/components/ui/checkbox"
import {
    DropdownMenu, DropdownMenuContent,
    DropdownMenuItem,
    DropdownMenuLabel,
    DropdownMenuSeparator,
    DropdownMenuTrigger
} from "@/components/ui/dropdown-menu"
import { Input } from "@/components/ui/input"
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { keepPreviousData, useQuery } from '@tanstack/react-query'
import { useMemo, useState } from "react"
import { Contact } from "@/types/contact"
import Loading from "../../../loading"
import { AddContactDialog } from "./AddContactDialog"
import { ContactsTable } from "./ContactsTable"
import { fetchData, itemsPerPage } from "./fetchData"
import { AddBulkContactsDialog } from "./AddBulkContactsDialog"
import ContactBrowserFactory from "@/lib/repositories/contacts/ContactBrowserFactory"
import { useSupabase } from "@/components/supabase-provider"

export default function ContactsClient() {
    const { supabase } = useSupabase()
    const [isExporting, setIsExporting] = useState(false)
    const [isExportDialogOpen, setIsExportDialogOpen] = useState(false)
    const [exportStartDate, setExportStartDate] = useState("")
    const [exportEndDate, setExportEndDate] = useState("")
    const [exportError, setExportError] = useState("")
    const columns = useMemo<ColumnDef<Contact>[]>(
        () => [
            // {
            //     id: "select",
            //     size: 40,
            //     header: ({ table }) => (
            //         <Checkbox
            //             checked={table.getIsAllPageRowsSelected()}
            //             onCheckedChange={(value) => table.toggleAllPageRowsSelected(!!value)}
            //             aria-label="Select all"
            //         />
            //     ),
            //     cell: ({ row }) => (
            //         <Checkbox
            //             checked={row.getIsSelected()}
            //             onCheckedChange={(value) => row.toggleSelected(!!value)}
            //             aria-label="Select row"
            //         />
            //     ),
            //     enableSorting: false,
            //     enableHiding: false,
            // },
            {
                accessorKey: "wa_id",
                header: "Number",
                size: 160,
                cell: ({ row }) => (
                    <div>{row.getValue("wa_id")}</div>
                ),
            },
            {
                accessorKey: "profile_name",
                header: 'Name',
                size: 280,
                cell: ({ row }) => <div>{row.getValue("profile_name")}</div>,
            },
            {
                accessorKey: "created_at",
                header: 'Created At',
                size: 280,
                cell: ({ row }) => <div>{row.getValue("created_at")}</div>,
            },
            {
                accessorKey: "tags",
                header: 'Tags',
                size: 280,
                cell: ({ row }) => <div>{(row.getValue('tags') as unknown as string[])?.join(", ")}</div>,
            },
            {
                id: "actions",
                size: 40,
                enableHiding: false,
                cell: ({ row }) => {
                    return (
                        <DropdownMenu>
                            <DropdownMenuTrigger asChild>
                                <Button variant="ghost" className="h-8 w-8 p-0">
                                    <span className="sr-only">Open menu</span>
                                    <MoreHorizontal className="h-4 w-4" />
                                </Button>
                            </DropdownMenuTrigger>
                            <DropdownMenuContent align="end">
                                <DropdownMenuLabel>Actions</DropdownMenuLabel>
                                <DropdownMenuSeparator />
                                <DropdownMenuItem>Coming soon</DropdownMenuItem>
                            </DropdownMenuContent>
                        </DropdownMenu>
                    )
                },
            },
        ],
        []
    )

    const [{ pageIndex, pageSize }, setPagination] =
        React.useState<PaginationState>({
            pageIndex: 0,
            pageSize: itemsPerPage,
        })
    const [ searchFilter, setSearchFilter ] = useState("")

    const fetchDataOptions = {
        pageIndex,
        pageSize,
        searchFilter
    }

    const dataQuery = useQuery({
        queryKey: ['data', fetchDataOptions],
        queryFn: () => fetchData(supabase, fetchDataOptions),
        placeholderData: keepPreviousData
    })
    const defaultData = React.useMemo(() => [], [])

    const pagination = React.useMemo(
        () => ({
            pageIndex,
            pageSize,
        }),
        [pageIndex, pageSize]
    )

    const [sorting, setSorting] = React.useState<SortingState>([])
    const [columnVisibility, setColumnVisibility] =
        React.useState<VisibilityState>({})
    const [rowSelection, setRowSelection] = React.useState({})

    const table = useReactTable<Contact>({
        data: dataQuery.data?.rows ?? defaultData,
        columns,
        manualPagination: true,
        pageCount: dataQuery.data?.pageCount ?? -1,
        onSortingChange: setSorting,
        getCoreRowModel: getCoreRowModel(),
        getPaginationRowModel: getPaginationRowModel(),
        getSortedRowModel: getSortedRowModel(),
        getFilteredRowModel: getFilteredRowModel(),
        onColumnVisibilityChange: setColumnVisibility,
        onRowSelectionChange: setRowSelection,
        onPaginationChange: setPagination,
        state: {
            sorting,
            columnVisibility,
            rowSelection,
            pagination,
        },
    })

    function toIsoDateStart(dateStr: string): string | undefined {
        if (!dateStr) return undefined
        const d = new Date(`${dateStr}T00:00:00.000Z`)
        return d.toISOString()
    }

    function toIsoDateEnd(dateStr: string): string | undefined {
        if (!dateStr) return undefined
        const d = new Date(`${dateStr}T23:59:59.999Z`)
        return d.toISOString()
    }

    async function exportAllContactsAsCsv(startDate?: string, endDate?: string) {
        try {
            setIsExporting(true)
            const repo = ContactBrowserFactory.getInstance(supabase)
            const csvRows: string[] = []
            // Header inspired by example-bulk-contacts.csv
            csvRows.push(["Name","Number (with country code)","Tags (Comma separated)"].join(","))

            const pageSize = 1000
            let page = 0
            while (true) {
                const offset = page * pageSize
                const filters: any[] = []
                if (startDate) {
                    filters.push({ column: 'created_at', operator: 'gte', value: startDate })
                }
                if (endDate) {
                    filters.push({ column: 'created_at', operator: 'lte', value: endDate })
                }
                const { rows } = await repo.getContacts(filters.length ? filters : undefined, { column: 'created_at', options: { ascending: false } }, { limit: pageSize, offset }, false)
                if (!rows || rows.length === 0) break
                for (const c of rows) {
                    const name = (c.profile_name ?? '').toString().replaceAll('"','""')
                    const number = (c.wa_id ?? '').toString().replaceAll('"','""')
                    const tags = (c.tags ?? []).join("; ").replaceAll('"','""')
                    // Quote fields to be safe; use semicolon between tags to avoid CSV conflicts
                    csvRows.push([`"${name}"`,`"${number}"`,`"${tags}"`].join(","))
                }
                if (rows.length < pageSize) break
                page++
            }

            const blob = new Blob([csvRows.join("\n")], { type: 'text/csv;charset=utf-8;' })
            const url = URL.createObjectURL(blob)
            const a = document.createElement('a')
            a.href = url
            const now = new Date().toISOString().slice(0,19).replaceAll(':','-')
            a.download = `contacts-export-${now}.csv`
            document.body.appendChild(a)
            a.click()
            document.body.removeChild(a)
            URL.revokeObjectURL(url)
        } finally {
            setIsExporting(false)
        }
    }

    return (
        <div className="m-4 bg-white rounded-xl p-4">
            <div className="flex justify-between items-center py-4">
                <Input
                    placeholder="Search name..."
                    value={searchFilter}
                    onChange={(event) => setSearchFilter(event.target.value) }
                    className="max-w-sm"
                />
                <div className="space-x-2">
                    <Button className="ml-auto" onClick={() => { setExportError(""); setIsExportDialogOpen(true) }} disabled={isExporting}>
                        Export Contacts in CSV
                    </Button>
                    <AddBulkContactsDialog onSuccessfulAdd={dataQuery.refetch}>
                        <Button className="ml-auto">Add Bulk Contacts via CSV</Button>
                    </AddBulkContactsDialog>
                    <AddContactDialog onSuccessfulAdd={dataQuery.refetch}>
                        <Button className="ml-auto">Add Contact</Button>
                    </AddContactDialog>
                    
                </div>
            </div>
            <div className="rounded-md border relative">
                {dataQuery.isLoading && <div className="absolute block w-full h-full bg-gray-500 opacity-30">
                    <Loading/>
                </div>}
                <ContactsTable table={table} totalColumns={columns.length} />
            </div>
            <div className="flex items-center justify-end space-x-2 py-4">
                {/* <div className="flex-1 text-sm text-muted-foreground">
                    {table.getFilteredSelectedRowModel().rows.length} of {table.getFilteredRowModel().rows.length} row(s) selected
                </div> */}
                {table.getPageCount() != -1 && <div className="text-sm text-muted-foreground">
                    Page {table.getState().pagination.pageIndex + 1} of {table.getPageCount()}
                </div>}
                <div className="space-x-2">
                    <Button
                        variant="outline"
                        size="sm"
                        onClick={() => table.previousPage()}
                        disabled={!table.getCanPreviousPage()}
                    >
                        Previous
                    </Button>
                    <Button
                        variant="outline"
                        size="sm"
                        onClick={() => table.nextPage()}
                        disabled={!table.getCanNextPage()}
                    >
                        Next
                    </Button>
                </div>
            </div>
            <Dialog open={isExportDialogOpen} onOpenChange={(open) => { if (!isExporting) setIsExportDialogOpen(open) }}>
                <DialogContent className="sm:max-w-[500px]">
                    <DialogHeader>
                        <DialogTitle>Export Contacts</DialogTitle>
                        <DialogDescription>
                            Select a date range to filter by contact creation date. Leave blank for all contacts.
                        </DialogDescription>
                    </DialogHeader>
                    <div className="grid gap-4 py-2">
                        <div className="grid grid-cols-4 items-center gap-4">
                            <label className="col-span-2 text-right text-sm" htmlFor="export-start">Start date</label>
                            <Input id="export-start" type="date" value={exportStartDate} onChange={(e) => setExportStartDate(e.target.value)} className="col-span-2" />
                        </div>
                        <div className="grid grid-cols-4 items-center gap-4">
                            <label className="col-span-2 text-right text-sm" htmlFor="export-end">End date</label>
                            <Input id="export-end" type="date" value={exportEndDate} onChange={(e) => setExportEndDate(e.target.value)} className="col-span-2" />
                        </div>
                        {exportError && <span className="text-red-500 text-sm">{exportError}</span>}
                    </div>
                    <DialogFooter>
                        <Button variant="outline" onClick={() => setIsExportDialogOpen(false)} disabled={isExporting}>Cancel</Button>
                        <Button onClick={async () => {
                            if (exportStartDate && exportEndDate && exportStartDate > exportEndDate) {
                                setExportError('Start date must be before end date')
                                return
                            }
                            setExportError('')
                            const startIso = toIsoDateStart(exportStartDate)
                            const endIso = toIsoDateEnd(exportEndDate)
                            await exportAllContactsAsCsv(startIso, endIso)
                            setIsExportDialogOpen(false)
                        }} disabled={isExporting}>
                            {isExporting ? 'Exporting…' : 'Export'}
                        </Button>
                    </DialogFooter>
                </DialogContent>
            </Dialog>
        </div>
    )
}
