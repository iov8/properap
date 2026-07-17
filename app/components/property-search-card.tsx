const locations = ["Kingston", "Montego Bay", "Mandeville", "Ocho Rios", "Negril", "Lucea", "Morant Bay", "Port Antonio", "May Pen", "Spanish Town", "Discovery Bay", "Falmouth", "Black River", "Savanna-la-Mar"];
const propertyTypes = ["House", "Apartment", "Townhouse", "Land", "Commercial"];

function ArrowIcon() { return <svg aria-hidden="true" viewBox="0 0 24 24" width="20" height="20"><path d="M5 12h14M13 6l6 6-6 6" fill="none" stroke="currentColor" strokeWidth="1.8" /></svg>; }
function PinIcon() { return <svg aria-hidden="true" viewBox="0 0 24 24" width="21" height="21"><path d="M12 21s6-5.5 6-12a6 6 0 1 0-12 0c0 6.5 6 12 6 12Z" fill="none" stroke="currentColor" strokeWidth="1.7" /><circle cx="12" cy="9" r="2.2" fill="currentColor" /></svg>; }

export function PropertySearchCard({ hiddenFields = {} }: { hiddenFields?: Record<string, string> }) {
  return <form className="property-search" action="/properties" method="get">
    {Object.entries(hiddenFields).map(([name, value]) => <input key={name} type="hidden" name={name} value={value} />)}
    <label className="search-location"><span>Where are you looking?</span><span className="search-input-row"><PinIcon /><select name="location" defaultValue=""><option value="">Any city or area</option>{locations.map((location) => <option key={location} value={location}>{location}</option>)}</select></span></label>
    <label><span>Property type</span><select name="type" defaultValue=""><option value="">Any property</option>{propertyTypes.map((type) => <option key={type} value={type.toLowerCase()}>{type}</option>)}</select></label>
    <button type="submit" aria-label="Search properties"><ArrowIcon /></button>
  </form>;
}
