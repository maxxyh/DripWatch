import { NotebookApp } from "@/components/notebook-app"; export default async function BeanPage({params}:{params:Promise<{id:string}>}){return <NotebookApp view="bean" id={(await params).id}/>}
