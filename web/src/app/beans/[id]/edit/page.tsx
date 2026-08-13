import { BeanEditor } from "@/components/bean-editor"; export default async function EditBean({params}:{params:Promise<{id:string}>}){return <BeanEditor id={(await params).id}/>}
